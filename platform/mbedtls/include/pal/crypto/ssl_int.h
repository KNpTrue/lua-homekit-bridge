// Copyright (c) 2021-2022 KNpTrue and homekit-bridge contributors
//
// Licensed under the Apache License, Version 2.0 (the “License”);
// you may not use this file except in compliance with the License.
// See [CONTRIBUTORS.md] for the list of homekit-bridge project authors.

#ifndef PLATFORM_MBEDTLS_INCLUDE_PAL_CRYPTO_SSL_INT_H_
#define PLATFORM_MBEDTLS_INCLUDE_PAL_CRYPTO_SSL_INT_H_

#ifdef __cplusplus
extern "C" {
#endif

#include <mbedtls/ssl.h>

void pal_ssl_set_default_ca_chain(mbedtls_ssl_config *conf);

#ifdef __cplusplus
}
#endif

#endif  // PLATFORM_MBEDTLS_INCLUDE_PAL_CRYPTO_SSL_INT_H_
