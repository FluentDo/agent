/* -*- Mode: C; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*- */

/*  Fluent Bit
 *  ==========
 *  Copyright (C) 2019-2026 The Fluent Bit Authors
 *  Copyright (C) 2015-2018 Treasure Data Inc.
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

#include <fluent-bit.h>
#include <fluent-bit/flb_env.h>
#include <fluent-bit/flb_sds.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "flb_tests_internal.h"

static const char *expected_os_type()
{
#if defined(FLB_SYSTEM_WINDOWS)
    return "windows";
#elif defined(FLB_SYSTEM_MACOS)
    return "macos";
#elif defined(FLB_SYSTEM_LINUX)
    return "linux";
#else
    return "unknown";
#endif
}

void test_preset_env_defaults()
{
    struct flb_env *env;
    const char *hostname;
    const char *os_type;

    env = flb_env_create();
    if (!TEST_CHECK(env != NULL)) {
        TEST_MSG("flb_env_create failed");
        exit(1);
    }

    hostname = flb_env_get(env, "HOSTNAME");
    if (!TEST_CHECK(hostname != NULL && strlen(hostname) > 0)) {
        TEST_MSG("HOSTNAME preset is missing");
        flb_env_destroy(env);
        exit(1);
    }

    os_type = flb_env_get(env, "OS_TYPE");
    if (!TEST_CHECK(os_type != NULL && strlen(os_type) > 0)) {
        TEST_MSG("OS_TYPE preset is missing");
        flb_env_destroy(env);
        exit(1);
    }

    if (!TEST_CHECK(strcmp(os_type, expected_os_type()) == 0)) {
        TEST_MSG("OS_TYPE mismatch. Got=%s expect=%s", os_type, expected_os_type());
        flb_env_destroy(env);
        exit(1);
    }

    flb_env_destroy(env);
}

void test_preset_env_overrides()
{
    struct flb_env *env;
    const char *hostname;
    const char *os_type;
    const char *override_hostname = "env-test-host";
    const char *override_os_type = "env-test-os";
    int ret;
    char hostname_arg[128];
    char os_type_arg[128];

    snprintf(hostname_arg, sizeof(hostname_arg), "HOSTNAME=%s", override_hostname);
    snprintf(os_type_arg, sizeof(os_type_arg), "OS_TYPE=%s", override_os_type);

#if defined(FLB_SYSTEM_WINDOWS)
    ret = _putenv(hostname_arg);
    if (!TEST_CHECK(ret == 0)) {
        TEST_MSG("_putenv HOSTNAME failed");
        exit(1);
    }

    ret = _putenv(os_type_arg);
    if (!TEST_CHECK(ret == 0)) {
        TEST_MSG("_putenv OS_TYPE failed");
        exit(1);
    }
#else
    ret = setenv("HOSTNAME", override_hostname, 1);
    if (!TEST_CHECK(ret == 0)) {
        TEST_MSG("setenv HOSTNAME failed");
        exit(1);
    }

    ret = setenv("OS_TYPE", override_os_type, 1);
    if (!TEST_CHECK(ret == 0)) {
        TEST_MSG("setenv OS_TYPE failed");
        exit(1);
    }
#endif

    env = flb_env_create();
    if (!TEST_CHECK(env != NULL)) {
        TEST_MSG("flb_env_create failed");
        exit(1);
    }

    hostname = flb_env_get(env, "HOSTNAME");
    if (!TEST_CHECK(hostname != NULL && strcmp(hostname, override_hostname) == 0)) {
        TEST_MSG("HOSTNAME override lost. Got=%s expect=%s", hostname, override_hostname);
        flb_env_destroy(env);
        exit(1);
    }

    os_type = flb_env_get(env, "OS_TYPE");
    if (!TEST_CHECK(os_type != NULL && strcmp(os_type, override_os_type) == 0)) {
        TEST_MSG("OS_TYPE override lost. Got=%s expect=%s", os_type, override_os_type);
        flb_env_destroy(env);
        exit(1);
    }

    flb_env_destroy(env);

#if defined(FLB_SYSTEM_WINDOWS)
    _putenv("HOSTNAME=");
    _putenv("OS_TYPE=");
#else
    unsetenv("HOSTNAME");
    unsetenv("OS_TYPE");
#endif
}

/* https://github.com/fluent/fluent-bit/issues/6313 */
void test_translate_long_env()
{
    struct flb_env *env;
    flb_sds_t buf = NULL;
    char *long_env = "ABC_APPLICATION_TEST_TEST_ABC_FLUENT_BIT_SECRET_FLUENTD_HTTP_HOST";
    char long_env_ra[4096] = {0};
    char *env_val = "aaaaa";
    char putenv_arg[4096] = {0};
    size_t ret_size;
    int ret;

    ret_size = snprintf(&long_env_ra[0], sizeof(long_env_ra), "${%s}", long_env);
    if (!TEST_CHECK(ret_size < sizeof(long_env_ra))) {
        TEST_MSG("long_env_ra size error");
        exit(1);
    }
    ret_size = snprintf(&putenv_arg[0], sizeof(putenv_arg), "%s=%s", long_env, env_val);
    if (!TEST_CHECK(ret_size < sizeof(long_env_ra))) {
        TEST_MSG("putenv_arg size error");
        exit(1);
    }

    env = flb_env_create();
    if (!TEST_CHECK(env != NULL)) {
        TEST_MSG("flb_env_create failed");
        exit(1);
    }
#ifndef FLB_SYSTEM_WINDOWS
    ret = putenv(&putenv_arg[0]);
#else
    ret = _putenv(&putenv_arg[0]);
#endif
    if (!TEST_CHECK(ret == 0)) {
        TEST_MSG("setenv failed");
        flb_env_destroy(env);
        exit(1);
    }

    buf = flb_env_var_translate(env, &long_env_ra[0]);
    if (!TEST_CHECK(buf != NULL)) {
        TEST_MSG("flb_env_var_translate failed");
#ifndef FLB_SYSTEM_WINDOWS
        unsetenv(long_env);
#endif
        flb_env_destroy(env);
        exit(1);
    }

    if (!TEST_CHECK(strlen(buf) == strlen(env_val) && 0 == strcmp(buf, env_val))) {
        TEST_MSG("mismatch. Got=%s expect=%s", buf, env_val);
    }
    flb_sds_destroy(buf);
#ifndef FLB_SYSTEM_WINDOWS
    unsetenv(long_env);
#endif
    flb_env_destroy(env);
}


TEST_LIST = {
    { "preset_env_defaults"         , test_preset_env_defaults},
    { "preset_env_overrides"        , test_preset_env_overrides},
    { "translate_long_env"           , test_translate_long_env},
    { NULL, NULL }
};
