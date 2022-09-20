# msmtp oauth2token scripts

This is a set of scripts for integration with gmail and msmtp using oauth2 targeting different way
of storing secret - using plain text in separate file, straith in msmtp config, using pass or
libsecret.

## Create gmail api key

It is recommended to create separate api key for every server that will be using gmail account.

Create mail application with access to gmail api and with oauth2 credentials.

- Open console: https://console.cloud.google.com/apis/dashboard
- Login with your google credentials
- Create project, for example "mail" (it is best to have separate project just for mail)
- Click "ENABLE APIS AND SERVICES" and enable "Gmail API"
- Click "OAuth consent screen" on left side panel
  - Use project ID (don't confuse with project name) as "app name"
    - Usually for project named `mail` it looks like `mail-110001`
  - Use gmail email as user support email
  - Add gmail account address in test users
- Click "Credentials" on left side panel
  - Click "CREATE CREDENTIALS" and then "OAuth client ID"
  - Choose "Desktop app" type
  - Set name to differentiate server or server and use case
- Copy produced client id and client secret.

## Retrieve access token for gmail api key

Install gmail-oauth2-tools:

```
apt-get install python2
ln -sfv /usr/bin/python2 /usr/bin/python

wget https://raw.githubusercontent.com/google/gmail-oauth2-tools/master/python/oauth2.py -O /usr/local/bin/oauth2.py
chmod +x /usr/local/bin/oauth2.py
ln -sv /usr/local/bin/oauth2.py /usr/local/bin/oauth2
```

Obtain access token using client id/secret obtained before:

```
oauth2 --user=your_username@gmail.com \
    --client_id=[...].apps.googleusercontent.com \
    --client_secret=[...] \
    --generate_oauth2_token
```

You will be prompted to open a web page, open it, authenticate using your gmail account and approve
access. It will complain that "Google hasn’t verified this app", press "continue" link. After copy
authorization code from web page back to oauth2.py and it should produce 3 lines like below:

```
Refresh Token: [...]
Access Token: [...]
Access Token Expiration Seconds: [...]
```

Ensure you have saved client id, client secret and refresh token because they will be needed for
msmtp setup.

## Install msmtp

Install:

```
apt-get install msmtp msmtp-mta
```

Refuse AppArmor globally if asked or disable AppArmor profile just for msmtp:

```sh
ln -s /etc/apparmor.d/usr.bin.msmtp /etc/apparmor.d/disable/
apparmor_parser -R /etc/apparmor.d/usr.bin.msmtp
```

## Configure msmtp

### Option A: Configure msmtp with secret stored openly in separate config file

In the setup below client id/secret/refresh and session token/expiry will be saved in the same file.

Install wrapper:

```
wget https://raw.githubusercontent.com/sormy/msmtp-oauth2token/main/oauth2token-text.sh -O /usr/local/bin/oauth2token
chmod +x /usr/local/bin/oauth2token
```

Save secret to some unique config file, for example, `/var/mail/msmtp-your_username.conf`:

```
nano /var/mail/msmtp-your_username.conf

client-id=<client-id>
client-secret=<client-secret>
refresh=<refresh>
```

Create msmtp config:

```
nano /etc/msmtprc

account your_username@gmail.com
from your_username@gmail.com
user your_username@gmail.com
auth oauthbearer
passwordeval oauth2token your_username@gmail.com /var/mail/msmtp-your_username.conf
host smtp.gmail.com
port 587
tls on
tls_trust_file /etc/ssl/certs/ca-certificates.crt
account default : your_username@gmail.com
```

### Option B: Configure msmtp with secret stored openly in msmtp config file

In the setup below client id/secret/refresh will be hardcoded straight into msmpt and session
token/expiry will be saved in separate transient file that can be removed.

Install wrapper:

```
wget https://raw.githubusercontent.com/sormy/msmtp-oauth2token/main/oauth2token-text2.sh -O /usr/local/bin/oauth2token
chmod +x /usr/local/bin/oauth2token
```

Choose a config file for temporary token, for example, `/var/mail/msmtp-your_username.conf`:

Create msmtp config:

```
nano /etc/msmtprc

account your_username@gmail.com
from your_username@gmail.com
user your_username@gmail.com
auth oauthbearer
passwordeval oauth2token your_username@gmail.com <client-id> <client-secret> <refresh> /var/mail/msmtp-your_username.conf
host smtp.gmail.com
port 587
tls on
tls_trust_file /etc/ssl/certs/ca-certificates.crt
account default : your_username@gmail.com
```

### Option C: Configure msmtp with secret stored encrypted using pass

Application `pass` has a very deep wiring with gnupg, you will need to initialize both gnupg and
pass keyring before you can use it.

Install pass:

```
apt-get install pass
```

Install wrapper:

```
wget https://raw.githubusercontent.com/sormy/msmtp-oauth2token/main/oauth2token-pass.sh -O /usr/local/bin/oauth2token
chmod +x /usr/local/bin/oauth2token
```

NOTE: original version of wrapper is located here:
<https://raw.githubusercontent.com/harriott/ArchBuilds/f6cc8e5b10b1a472579d40c3e52116484e68ed18/jo/clm/msmtprc/oauth2tool.sh>

Initialize gnupg and pass as explained here: https://wiki.archlinux.org/title/Pass

Save secret under some unique key, for example, `msmtp-your_username`:

```
echo "<client-id>" | pass insert -e msmtp-your_username/client-id
echo "<client-secret>" | pass insert -e msmtp-your_username/client-secret
echo "<refresh>" | pass insert -e msmtp-your_username/refresh
```

Create msmtp config:

```
nano /etc/msmtprc

account your_username@gmail.com
from your_username@gmail.com
user your_username@gmail.com
auth oauthbearer
passwordeval oauth2token your_username@gmail.com msmtp-your_username
host smtp.gmail.com
port 587
tls on
tls_trust_file /etc/ssl/certs/ca-certificates.crt
account default : your_username@gmail.com
```

### Option D: Configure msmtp with secret stored encrypted using libsecret

Application `libsecret-tools` has a very deep wiring with gnome keyring and it is challenging to get
it working on headless server without X server.

Install libsecret-tools:

```
apt-get install libsecret-tools
```

Install wrapper:

```
wget https://raw.githubusercontent.com/sormy/msmtp-oauth2token/main/oauth2token-secret.sh -O /usr/local/bin/oauth2token
chmod +x /usr/local/bin/oauth2token
```

NOTE: original version of wrapper is located here:
<https://raw.githubusercontent.com/tenllado/dotfiles/master/config/msmtp/oauth2token>

Read more if you have questions here: https://wiki.archlinux.org/title/GNOME/Keyring

Save secret under some unique key, for example, `msmtp-your_username`:

```
echo "<client-id>" | secret-tool store msmtp-your_username client-id
echo "<client-secret>" | secret-tool store msmtp-your_username client-secret
echo "<refresh>" | secret-tool store msmtp-your_username refresh
```

Create msmtp config:

```
nano /etc/msmtprc

account your_username@gmail.com
from your_username@gmail.com
user your_username@gmail.com
auth oauthbearer
passwordeval oauth2token your_username@gmail.com msmtp-your_username
host smtp.gmail.com
port 587
tls on
tls_trust_file /etc/ssl/certs/ca-certificates.crt
account default : your_username@gmail.com
```

## Testing

Send email:

```
echo "test" | msmtp test_address@gmail.com
```

First email might get into "spam", ensure to take it out from "spam" to avoid mail from your server
to land here.

## (optional) Configure aliases

Add to `/etc/msmtprc`:

```
aliases /etc/aliases
```

Add aliases to `/etc/aliases`:

```
nano /etc/aliases

default: admin_name@domain.com
```

## Troubleshooting

If you are getting "sh: 1: oauth2token: Permission denied", then it is likely AppArmor.

You can disable AppArmor profile for msmtp:

```sh
ln -s /etc/apparmor.d/usr.bin.msmtp /etc/apparmor.d/disable/
apparmor_parser -R /etc/apparmor.d/usr.bin.msmtp
```

Use debug mode to see more details:

```
echo "test" | msmtp --debug test_address@gmail.com
```

## Other references

- https://github.com/tenllado/dotfiles/tree/master/config/msmtp
- https://luxing.im/mutt-integration-with-gmail-using-oauth/

## License

MIT
