#!/bin/bash

# adoption of:
# https://raw.githubusercontent.com/tenllado/dotfiles/master/config/msmtp/oauth2token
# https://raw.githubusercontent.com/harriott/ArchBuilds/f6cc8e5b10b1a472579d40c3e52116484e68ed18/jo/clm/msmtprc/oauth2tool.sh
#
# first argument: email address
# second argument: the attribute namespace ($att) for the pass 
#                  (values are $att/client-id, $att/client-secret, $att/refresh, $att/token and $att/token-expire)
#
# This script assumes that you have done the following:
#
#   1. Set up your Gmail API. I did it with the Python Quickstart
#        https://developers.google.com/gmail/api/quickstart/python
#      You will receive your Client ID and your Client Secret.
#
#   2. Install oauth2.py to PATH, chmod +x oauth2.py
#        https://github.com/google/gmail-oauth2-tools/blob/master/python/oauth2.py
#
#   3. Generated your refresh token with a preliminary run of Gmail's  oauth2.py
#
#        $ oauth2.py --user=<username@gmail.com> --client_id=<client-id> \
#            --client_secret=<client-secret> --generate_oauth2_token
#
#   4. Configured your ~/.password-store
#
#        echo <client-id>     | pass insert -e username@gmail.com/client-id
#        echo <client-secret> | pass insert -e username@gmail.com/client-secret
#        echo <refresh>       | pass insert -e username@gmail.com/refresh
#        echo 0               | pass insert -e username@gmail.com/token-expire
#
#        Note: this script will first check if your access token is expired
#          if no, it will just grab it from your ~/.password-store
#          if yes, it will rerun oauth2.py to generate a new token and expiry time
#            and save them both in your ~/.password-store
#
# Example ~/.msmtprc:
#
#        defaults
#        tls	on
#        tls_trust_file	/etc/ssl/certs/ca-certificates.crt
#        logfile	~/.config/msmtp/msmtp.log
#
#        account username
#        auth oauthbearer
#        host smtp.gmail.com
#        port 587
#        from username@gmail.com
#        user username@gmail.com
#        passwordeval oauth2token username@gmail.com username@gmail.com
# 
# Verify:
#
#        $ echo "test" | msmtp -a username@gmail.com target@gmail.com
#

account="$1"
att="$2"

get_access_token() {
    { IFS= read -r tokenline && IFS= read -r expireline; } < \
    <(oauth2.py --user="$account" \
    --client_id="$(pass "$att"/client-id)" \
    --client_secret="$(pass "$att"/client-secret)" \
    --refresh_token="$(pass "$att"/refresh)")

    token=${tokenline#Access Token: }
    expire=${expireline#Access Token Expiration Seconds: }
}

token="$(pass "$att"/token)"
expire="$(pass "$att"/token-expire)"
now=$(date +%s)

if [[ $token && $expire && $now -lt $((expire - 60)) ]]; then
    echo "$token"
else
    get_access_token
    echo "$token" | pass insert -e "$att"/token
    expire=$((now + expire))
    echo $expire | pass insert -e "$att"/token-expire
    echo "$token"
fi
