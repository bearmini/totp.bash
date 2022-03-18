# totp.bash

Time-based one-time password ([RFC6238](https://datatracker.ietf.org/doc/html/rfc6238) compliant) tool which requires only bash (and openssl).

# How to use

## Generate TOTP URI

```sh
totp.bash generate_totp_uri "$secret_plain_text"
```

## Parse TOTP URI and extact secret plain text

```sh
totp.bash extract_secret_plain_text_from_totp_uri "$totp_uri"
```

Store the secret to secure place on your own responsibility.


## Get Time-based one-time password

```sh
totp.bash calculate_totp "$secret_plain_text"
```

