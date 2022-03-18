# totp.bash

Time-based one-time password ([RFC6238](https://datatracker.ietf.org/doc/html/rfc6238) compliant) tool which requires only bash (and openssl).

# How to use

## Generate TOTP URI

```sh
# Generate TOTP URI with plain text secret
./totp.bash generate_totp_uri "$issuer" "$account_name" "$secret_plain_text"
```

or

```sh
# Generate TOTP URI with hex string secret
./totp.bash generate_totp_uri_with_hex_key "$issuer" "$account_name" "$secret_hex_string"
```


Examples:

```sh
./totp.bash generate_totp_uri TestIssuer TestAccountName P@ssw0rd
# => otpauth://totp/TestIssuer:TestAccountName?secret=KBAHG43XGBZGI===&issuer=TestIssuer&algorithm=SHA1&digits=6&period=30
```

```sh
./totp.bash generate_totp_uri_with_hex_key TestIssuer TestAccountName 5040737377307264
# => otpauth://totp/TestIssuer:TestAccountName?secret=KBAHG43XGBZGI===&issuer=TestIssuer&algorithm=SHA1&digits=6&period=30
```

## Parse TOTP URI and extract secret

```sh
# Extract secret as plain text
./totp.bash extract_secret_plain_text_from_totp_uri "$totp_uri"
```

or

```sh
# Extract secret as hex string
./totp.bash extract_secret_hex_string_from_totp_uri "$totp_uri"
```

❗❗❗ Note ❗❗❗

🔐 Store the secret to secure place on your own responsibility.


Examples:

```sh
./totp.bash extract_secret_plain_text_from_totp_uri 'otpauth://totp/TestIssuer:TestAccountName?secret=KBAHG43XGBZGI===&issuer=TestIssuer&algorithm=SHA1&digits=6&period=30'
# => P@ssw0rd
```

```sh
./totp.bash extract_secret_hex_string_from_totp_uri 'otpauth://totp/TestIssuer:TestAccountName?secret=KBAHG43XGBZGI===&issuer=TestIssuer&algorithm=SHA1&digits=6&period=30'
# => 5040737377307264
```


## Get Time-based one-time password

```sh
./totp.bash calculate_totp "$secret_plain_text"
```

or

```sh
./totp.bash calculate_totp_with_hex_key "$secret_hex_string"
```

Examples:

```sh
./totp.bash calculate_totp P@ssword
# => 224526 (may differ time to time)
```

or

```sh
./totp.bash calculate_totp_with_hex_key 5040737377307264
# => 358915 (may differ time to time)
```
