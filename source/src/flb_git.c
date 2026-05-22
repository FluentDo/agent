/* -*- Mode: C; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*- */

/*  Fluent Bit
 *  ==========
 *  Copyright (C) 2024-2026 The Fluent Bit Authors
 *
 *  Licensed under the Apache License, Version 2.0 (the "License");
 *  you may not use this file except in compliance with the License.
 *  You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 *  Unless required by applicable law or agreed to in writing, software
 *  distributed under the License is distributed on an "AS IS" BASIS,
 *  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 *  See the License for the specific language governing permissions and
 *  limitations under the License.
 */

#include <fluent-bit/flb_git.h>
#include <fluent-bit/flb_mem.h>
#include <fluent-bit/flb_log.h>
#include <fluent-bit/flb_sds.h>
#include <fluent-bit/flb_str.h>

#include <git2.h>
#include <string.h>

/* Initialize git library */
int flb_git_init()
{
    return git_libgit2_init();
}

/* Shutdown git library */
void flb_git_shutdown()
{
    git_libgit2_shutdown();
}

/* Create git context */
struct flb_git_ctx *flb_git_ctx_create(const char *url, const char *ref, const char *local_path)
{
    struct flb_git_ctx *ctx;

    if (!url || !ref || !local_path) {
        return NULL;
    }

    ctx = flb_calloc(1, sizeof(struct flb_git_ctx));
    if (!ctx) {
        return NULL;
    }

    ctx->url = flb_strdup(url);
    ctx->ref = flb_strdup(ref);
    ctx->local_path = flb_strdup(local_path);
    ctx->repo = NULL;

    if (!ctx->url || !ctx->ref || !ctx->local_path) {
        flb_git_ctx_destroy(ctx);
        return NULL;
    }

    return ctx;
}

/* Destroy git context */
void flb_git_ctx_destroy(struct flb_git_ctx *ctx)
{
    if (!ctx) {
        return;
    }

    if (ctx->repo) {
        git_repository_free((git_repository *)ctx->repo);
    }

    if (ctx->url) {
        flb_free(ctx->url);
    }

    if (ctx->ref) {
        flb_free(ctx->ref);
    }

    if (ctx->local_path) {
        flb_free(ctx->local_path);
    }

    flb_free(ctx);
}

/* Helper: Convert git OID to flb_sds string */
static flb_sds_t git_oid_to_sds(const git_oid *oid)
{
    char oid_str[GIT_OID_HEXSZ + 1];
    git_oid_tostr(oid_str, sizeof(oid_str), oid);
    return flb_sds_create(oid_str);
}

/* Get remote HEAD SHA for a reference */
flb_sds_t flb_git_remote_sha(struct flb_git_ctx *ctx)
{
    int ret;
    git_remote *remote = NULL;
    const git_remote_head **refs;
    size_t refs_len;
    flb_sds_t sha = NULL;
    char ref_name[FLB_GIT_REF_NAME_MAX];
    size_t i;

    if (!ctx || !ctx->url || !ctx->ref) {
        return NULL;
    }

    /* Create remote */
    ret = git_remote_create_anonymous(&remote, NULL, ctx->url);
    if (ret != 0) {
        return NULL;
    }

    /* Connect to remote */
    ret = git_remote_connect(remote, GIT_DIRECTION_FETCH, NULL, NULL, NULL);
    if (ret != 0) {
        git_remote_free(remote);
        return NULL;
    }

    /* Get remote refs */
    ret = git_remote_ls(&refs, &refs_len, remote);
    if (ret != 0) {
        git_remote_disconnect(remote);
        git_remote_free(remote);
        return NULL;
    }

    /* Build full ref name */
    snprintf(ref_name, sizeof(ref_name), "refs/heads/%s", ctx->ref);

    /* Find matching ref */
    for (i = 0; i < refs_len; i++) {
        if (strcmp(refs[i]->name, ref_name) == 0) {
            sha = git_oid_to_sds(&refs[i]->oid);
            break;
        }
    }

    git_remote_disconnect(remote);
    git_remote_free(remote);

    return sha;
}

/* Clone or update repository */
int flb_git_sync(struct flb_git_ctx *ctx)
{
    int ret;
    git_repository *repo = NULL;
    git_remote *remote = NULL;
    git_object *target = NULL;
    git_checkout_options checkout_opts = GIT_CHECKOUT_OPTIONS_INIT;
    char ref_name[FLB_GIT_REF_NAME_MAX];

    if (!ctx) {
        return -1;
    }

    /* Try to open existing repository */
    ret = git_repository_open(&repo, ctx->local_path);
    if (ret == 0) {
        /* Repository exists, fetch updates */
        ret = git_remote_lookup(&remote, repo, "origin");
        if (ret != 0) {
            git_repository_free(repo);
            return -1;
        }

        ret = git_remote_fetch(remote, NULL, NULL, NULL);
        git_remote_free(remote);

        if (ret != 0) {
            git_repository_free(repo);
            return -1;
        }
    } else {
        /* Repository doesn't exist, clone it */
        ret = git_clone(&repo, ctx->url, ctx->local_path, NULL);
        if (ret != 0) {
            return -1;
        }
    }

    /* Checkout specific ref */
    snprintf(ref_name, sizeof(ref_name), "refs/remotes/origin/%s", ctx->ref);

    ret = git_revparse_single(&target, repo, ref_name);
    if (ret != 0) {
        /* Try without remotes prefix */
        snprintf(ref_name, sizeof(ref_name), "refs/heads/%s", ctx->ref);
        ret = git_revparse_single(&target, repo, ref_name);
        if (ret != 0) {
            git_repository_free(repo);
            return -1;
        }
    }

    checkout_opts.checkout_strategy = GIT_CHECKOUT_FORCE;
    ret = git_checkout_tree(repo, target, &checkout_opts);
    git_object_free(target);

    if (ret != 0) {
        git_repository_free(repo);
        return -1;
    }

    /* Update HEAD */
    git_repository_set_head(repo, ref_name);

    /* Store repository handle */
    if (ctx->repo) {
        git_repository_free((git_repository *)ctx->repo);
    }
    ctx->repo = repo;

    return 0;
}

/* Get file content from repository */
flb_sds_t flb_git_get_file(struct flb_git_ctx *ctx, const char *file_path)
{
    int ret;
    git_repository *repo;
    git_reference *head = NULL;
    git_commit *commit = NULL;
    git_tree *tree = NULL;
    git_tree_entry *entry = NULL;
    git_blob *blob = NULL;
    flb_sds_t content = NULL;
    const git_oid *oid;

    if (!ctx || !file_path) {
        return NULL;
    }

    /* Open repository if not already open */
    if (!ctx->repo) {
        ret = git_repository_open(&repo, ctx->local_path);
        if (ret != 0) {
            return NULL;
        }
        ctx->repo = repo;
    } else {
        repo = (git_repository *)ctx->repo;
    }

    /* Get HEAD reference */
    ret = git_repository_head(&head, repo);
    if (ret != 0) {
        return NULL;
    }

    /* Get commit from HEAD */
    oid = git_reference_target(head);
    ret = git_commit_lookup(&commit, repo, oid);
    git_reference_free(head);
    if (ret != 0) {
        return NULL;
    }

    /* Get tree from commit */
    ret = git_commit_tree(&tree, commit);
    git_commit_free(commit);
    if (ret != 0) {
        return NULL;
    }

    /* Get tree entry for file */
    ret = git_tree_entry_bypath(&entry, tree, file_path);
    git_tree_free(tree);
    if (ret != 0) {
        return NULL;
    }

    /* Get blob from tree entry */
    oid = git_tree_entry_id(entry);
    ret = git_blob_lookup(&blob, repo, oid);
    git_tree_entry_free(entry);
    if (ret != 0) {
        return NULL;
    }

    /* Create SDS string with blob content */
    content = flb_sds_create_len((const char *)git_blob_rawcontent(blob),
                                  git_blob_rawsize(blob));

    git_blob_free(blob);

    return content;
}

/* Get current local HEAD SHA */
flb_sds_t flb_git_local_sha(struct flb_git_ctx *ctx)
{
    int ret;
    git_repository *repo;
    git_oid oid;
    git_reference *head = NULL;
    flb_sds_t sha = NULL;

    if (!ctx) {
        return NULL;
    }

    /* Open repository if not already open */
    if (!ctx->repo) {
        ret = git_repository_open(&repo, ctx->local_path);
        if (ret != 0) {
            return NULL;
        }
        ctx->repo = repo;
    } else {
        repo = (git_repository *)ctx->repo;
    }

    /* Get HEAD reference */
    ret = git_repository_head(&head, repo);
    if (ret != 0) {
        return NULL;
    }

    /* Get OID from reference */
    git_oid_cpy(&oid, git_reference_target(head));
    git_reference_free(head);

    /* Convert OID to string */
    sha = git_oid_to_sds(&oid);

    return sha;
}
