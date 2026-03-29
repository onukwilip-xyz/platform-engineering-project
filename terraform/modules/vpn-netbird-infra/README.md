# VPN Netbird Infrastructure Module

Configures Netbird VPN resources: routing peer groups, setup keys, network routes, and (optionally) a Google Workspace identity provider.

## Google Workspace Identity Provider

The Google Workspace IdP integration is **optional** and controlled by the `enable_google_idp` variable. When enabled, it registers Google Workspace as an OIDC identity provider in Netbird so that users can sign in with their organizational Google accounts.

### Pre-requisites

Before setting `enable_google_idp = true`, complete these one-time manual steps in the Google Cloud Console:

#### 1. Configure the OAuth Consent Screen

1. Go to **APIs & Services > OAuth consent screen** in the GCP project where Netbird runs
2. Select **Internal** user type (restricts login to your Google Workspace organization)
3. Set:
   - **App name**: e.g. `NetBird VPN`
   - **User support email**: your admin or group email
   - **Scopes**: `email`, `profile`, `openid`
4. Save

#### 2. Create an OAuth 2.0 Client ID

1. Go to **APIs & Services > Credentials**
2. Click **Create Credentials > OAuth client ID**
3. Set:
   - **Application type**: Web application
   - **Name**: e.g. `NetBird`
4. Leave **Authorized redirect URIs** empty for now (Netbird will provide the redirect URI after the identity provider is created)
5. Copy the **Client ID** and **Client Secret**

#### 3. Set Terraform Variables

Add the credentials to your `.tfvars` file:

```hcl
enable_google_idp      = true
google_oauth_client_id     = "<YOUR_CLIENT_ID>"
google_oauth_client_secret = "<YOUR_CLIENT_SECRET>"
```

Then run `terraform apply`.

#### 4. Add the Redirect URI

After `terraform apply` completes, the output will display a redirect URI from Netbird. Add it to the OAuth client:

1. Go to **APIs & Services > Credentials**
2. Click the **NetBird** OAuth client
3. Under **Authorized redirect URIs**, click **ADD URI**
4. Paste the redirect URI from the Terraform output
5. Click **Save**

The redirect URI is also stored in Parameter Manager (`netbird_idp_redirect_uri_parameter_id`) for reference.

## User Invitations

The `netbird_users` variable accepts a list of users to invite to the Netbird VPN:

```hcl
netbird_users = [
  { name = "Prince Onukwili", email = "prince@example.com", role = "admin" },
  { name = "Jane Doe",        email = "jane@example.com",   role = "user" },
]
```

Valid roles: `admin`, `user`, `owner`. Leave as `[]` to skip.

### Sharing invite links

Netbird's local identity provider does not send invitation emails. When `terraform apply` creates the invites, they are registered in Netbird but the users are **not** automatically notified.

To share an invite link with a user:

1. Go to the **Netbird Dashboard > Users** page
2. Find the invited user
3. Click **Regenerate invite** to generate a fresh invite link
4. Copy the link and send it to the user manually (e.g. via email or chat)

The user can then open the link in their browser, set their password, and log in to the VPN.