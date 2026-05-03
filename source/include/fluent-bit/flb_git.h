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

#ifndef FLB_GIT_H
#define FLB_GIT_H

#include <fluent-bit/flb_info.h>
#include <fluent-bit/flb_sds.h>

/* Buffer size for git reference names (e.g., refs/heads/main) */
#define FLB_GIT_REF_NAME_MAX 256

/* Forward declaration for libgit2 type */
struct git_repository;

/* Git context for repository operations */
struct flb_git_ctx {
    char *url;              /* Repository URL (HTTP/SSH) */
    char *ref;              /* Branch/tag/commit reference */
    char *local_path;       /* Local clone path */
    struct git_repository *repo;  /* git_repository pointer (libgit2) */
};

/* Initialize git library */
int flb_git_init();

/* Shutdown git library */
void flb_git_shutdown();

/* Create git context */
struct flb_git_ctx *flb_git_ctx_create(const char *url, const char *ref, const char *local_path);

/* Destroy git context */
void flb_git_ctx_destroy(struct flb_git_ctx *ctx);

/* Get remote HEAD SHA for a reference (fast check, no clone) */
flb_sds_t flb_git_remote_sha(struct flb_git_ctx *ctx);

/* Clone or update repository to local path */
int flb_git_sync(struct flb_git_ctx *ctx);

/* Get file content from repository at specific path */
flb_sds_t flb_git_get_file(struct flb_git_ctx *ctx, const char *file_path);

/* Get current local HEAD SHA */
flb_sds_t flb_git_local_sha(struct flb_git_ctx *ctx);

#endif /* FLB_GIT_H */
