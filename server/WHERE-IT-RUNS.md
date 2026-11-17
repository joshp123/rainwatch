Written by AI on 2026.11.17 by model gpt-6 astra; trimmed for this public repo by claude opus 5.5.

# Where RainWatch's job runs

**Run the job as a scheduled AWS Lambda function in Ireland, beside its S3 bucket.** Josh ruled out the gohome VPS (14 November design): it holds his house's credentials, and a job that only needs KNMI's key and the right to write two files should not sit beside them. This supersedes the placement in `FIRST-PRINCIPLES.md`; S3 and CloudFront remain the delivery path.

## RainWatch
All four options keep serving the last S3 publication when the producer fails. Once its forecast is an hour old the app must show **“No data”**; an outage shorter than an hour can cross that boundary because the published forecast is already several minutes old. A CDN cannot make it fresh. KNMI failure affects every option. AWS delivery failure affects every option too.

Costs below are for the producer, per month, excluding tax unless stated. S3/CloudFront delivery costs are shared by all choices. Two publication writes per five-minute run cost about $0.09 per 30 days before storage and reads.

| Location | What could leak or be abused | What fails with it | Monthly producer cost | Build and upkeep |
| --- | --- | --- | --- | --- |
| Existing CAX21 after gohome leaves | KNMI key and upload-only AWS key **after a clean rebuild and revocation of old house access**. Simply stopping gohome leaves old secrets, host identities and state behind. | New rain forecasts; no house function after full separation. | €10.99 including IPv4; €13.30 with Dutch VAT. €0 extra cash only while keeping it anyway. | Rebuild as a dedicated host, narrow network access, reuse the Nix timer; then patch and monitor a whole OS. Several hours after migration, estimated. |
| New dedicated VPS | KNMI key and upload-only AWS key; no house secrets or house-network grants. Upload-only still permits forged forecasts, overwriting `latest` and extra storage charges. | New rain forecasts only. | CX23: **€5.49 + €0.50 IPv4 = €5.99**, €7.25 with VAT, but currently marked unavailable. CPX12 with 2 GB: **€9.99 Helsinki / €11.99 Nuremberg including IPv4**, €12.09 / €14.51 with VAT. | A small NixOS host and existing timer, usually half a day; OS updates, credentials and freshness monitoring remain. Check capacity before purchase. |
| mini-server-1 | Both rain keys, with the house/media/agent authority exposed if isolation fails. Does not satisfy the reason for rejecting the hub. | Rain publication during home power/internet outages, reboots or contention; other home services may fail at the same time. | €0 added hosting; unmeasured electricity. | A few hours to adapt the existing service. The observed long outages already exceed the app's freshness allowance. |
| Scheduled Lambda, same AWS account and region as S3 | KNMI key and temporary execution-role credentials. Scope them to rain output, private rain cache and that one secret; no house credentials or IAM administration. | New rain forecasts on schedule/function failure. AWS account or regional incidents can affect both production and delivery. | Compute/schedule likely **$0 within shared free allowances**; approximately **$2.88 compute** at 2 GiB × 10 seconds × 8,640 runs if the compute allowance is used up. Add cents for requests/cache and small secret/log/monitor charges. | More initial adaptation: roughly 1–2 engineering days, estimated. Maintain Python/native dependencies and IAM; AWS maintains the host. |

Prices were read from the official pages on 17 November; their displayed totals already include IPv4. CPX02 has only 1 GB: Helsinki €5.49 / Nuremberg €6.49 including IPv4, but little headroom for the 0.5 GB job plus OS and peak variation. CPX stock was not verified in an account. [Cost-optimised plans](https://www.hetzner.com/cloud/cost-optimized/), [regular plans](https://www.hetzner.com/cloud/regular-performance/), [IPv4 pricing](https://docs.hetzner.com/cloud/servers/primary-ips/overview/).

### What Lambda needs

Keep `build()` and add a handler plus S3 storage adapter. Package NumPy/h5py for Linux; start at 2 GiB and measure a rainy run. Nine seconds is not a Lambda benchmark. Its memory and 15-minute runtime limits suffice. [AWS limits](https://docs.aws.amazon.com/lambda/latest/dg/gettingstarted-limits.html).

The main work is durable state: temporary disk cannot preserve the observed-radar cache or completed-run marker across cold starts. Keep those in private S3 storage, cache forecast inputs for retries, allow one concurrent execution, skip duplicate/stale events and prevent older runs replacing newer ones. Publish the pack before `latest`. Verify KNMI's one-fetch rule through retries and interrupted publication. Extend lifecycle cleanup and replace the upload-only user with a restricted execution role that can also read this private cache.

Use Scheduler, a restricted KNMI secret, bounded logs and an independent forecast-age check; no public function URL or VPC/NAT gateway. Test cold starts, duplicates, interrupted uploads, recovery and stale data on the watch. Nothing was deployed or benchmarked here.

At 2 GiB and ten seconds, 8,640 runs use 172,800 GB-seconds against Lambda's shared 400,000 free allowance; Ireland x86 compute is $0.0000166667/GB-second. Scheduler includes 14 million invocations, then $1/million. Even at 30 seconds, gross compute is about $8.64/month. Account-wide free-tier consumption was not inspected. [Lambda pricing](https://aws.amazon.com/lambda/pricing/), [Ireland rate card](https://pricing.us-east-1.amazonaws.com/offers/v1.0/aws/AWSLambda/current/eu-west-1/index.json), [Scheduler pricing](https://aws.amazon.com/eventbridge/pricing/).
