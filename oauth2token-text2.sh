#!/bin/bash

# Usage: oauth2token <account> <client_id> <client_secret> <refresh_token> <token_file>

# google account name like username@gmail.com
account="$1"
# given by google console when credentials are created
client_id="$2"
# given by google console when credentials are created
client_secret="$3"
# given by google oauth2 script when called with --generate_oauth2_token
refresh_token="$4"
# file where to keep transient expiring oauth2 token
token_file="$5"

get_access_token() {
    { IFS= read -r tokenline && IFS= read -r expireline; } < \
    <(oauth2.py --user="$account" \
    --client_id="$client_id" \
    --client_secret="$client_secret" \
    --refresh_token="$refresh_token")

    token=${tokenline#Access Token: }
    expire=${expireline#Access Token Expiration Seconds: }
}

token="$(cut -d " " -f 1 2> /dev/null < "$token_file")"
expire="$(cut -d " " -f 2 2> /dev/null < "$token_file")"
now=$(date +%s)

if [[ $token && $expire && $now -lt $((expire - 60)) ]]; then
    echo "$token"
else
    get_access_token
    expire=$((now + expire))
    echo "$token $expire" > "$token_file"
    echo "$token"
fi
