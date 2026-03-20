To use this module, you must aquire a domain name, e.g. `onukwilip.xyz`
Afterwards, generate a Cloudflare API token with the 

- `Zone - DNS | Edit (for the domain)` 
- `Zone - Zone | Read (for the domain)` permissons 
- Then specify the Zone, e.g. `onukwilip.xyz`

Pass the API token into the `cloudflare_api_token` variable.

Copy the Zone ID from the right sidebar, at the bottom of the *Overview page*, and pass it into the `cloudflare_zone_id` variable