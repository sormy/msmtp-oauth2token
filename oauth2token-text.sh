#!/bin/bash

# google account name like username@gmail.com
account="$1"
# file where client-id, client-secret, refresh are available 
# and where token and token-expire will be written
filename="$2"

secret_lookup() {
    local file="$1"
    local key="$2"
    grep -s '^'"$key"'=' "$file" | sed 's/^[^=]*=//'
}

secret_store() {
    local file="$1"
    local key="$2"
    local value="$3"
    if grep -s -q "^$key=" "$file"; then
        sed -i "/^$key=.*$/c\\$key=$value" "$file"
    else
        echo "$key=$value" >> "$file"
    fi
}

get_access_token() {
    { IFS= read -r tokenline && IFS= read -r expireline; } < \
    <(oauth2.py --user="$account" \
    --client_id="$(secret_lookup "$filename" client-id)" \
    --client_secret="$(secret_lookup "$filename" client-secret)" \
    --refresh_token="$(secret_lookup "$filename" refresh)")

    token=${tokenline#Access Token: }
    expire=${expireline#Access Token Expiration Seconds: }
}

token="$(secret_lookup "$filename" token)"
expire="$(secret_lookup "$filename" token-expire)"
now=$(date +%s)

if [[ $token && $expire && $now -lt $((expire - 60)) ]]; then
    echo "$token"
else
    get_access_token
    secret_store "$filename" token "$token"
    expire=$((now + expire))
    secret_store "$filename" token-expire "$expire"
    echo "$token"
fi
