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