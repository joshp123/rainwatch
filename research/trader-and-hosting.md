<!-- Written by AI on 2026.11.14 by model claude-sonnet-5-5 (Claude Sonnet 5.5), for Josh. All sources read on 2026-11-13/14. Nothing was signed up for or paid for. -->

# EU trader status and hosting for Rain

## Recommendations

1. **Trader status: stay an individual and put a rented postbox address on the store page.** A Dutch BV would cost roughly €1,800 to €5,500 a year to run and still shows an address on the store page. A postbox from PriPost costs about €6.55 a month plus a one-off €18 to €31 (excluding VAT), so about €100 in the first year. If Rain launches free, with no ads and no in-app purchases, declaring "not a trader" costs €0 and shows no address, but whether that is true is a legal call that only Josh can make.
2. **Hosting: not ChatGPT Sites. Use AWS.** ChatGPT Sites cannot run the Python job and costs more than AWS at Rain's traffic. On AWS (scheduled Lambda, S3, CloudFront) the job should cost about $0 to $5 a month. Cloudflare would cost at least $5 a month and needs untested Python-in-WebAssembly.

---

## 1. EU trader status

### What Apple displays and checks

- Apple must verify and display the trader's address, phone number and email on the App Store product page in all 27 EU countries ([Apple: DSA trader requirements](https://developer.apple.com/help/app-store-connect/manage-compliance-information/manage-european-union-digital-services-act-trader-requirements/)).
- Individuals enter an "Address or P.O. Box", phone and email. Organisations enter only phone and email, because Apple shows the address tied to the organisation's D-U-N-S number (same page).
- Apple checks the email and phone with two-factor codes (manual check if the phone cannot receive codes). It asks for "a current document that verifies your business name and address" (same page).
- A P.O. box is accepted. Apple then wants a document "that reflects your association with this alternate address (for example, a receipt or bill)" (same page). Apple's sister page for Apple Books says an individual may prove their address with a government photo ID ([Apple Books DSA page](https://itunespartner.apple.com/books/support/5401-manage-digital-services-act-compliance-information)). I did not find the same sentence for the App Store page, so the ID route is likely but unconfirmed.
- Not a trader: nothing is displayed, but EU consumers are told that consumer-protection rights do not apply to contracts with the developer (Apple page). The status can be changed per app later.
- Apple lists the trader factors: revenue from the app (paid, in-app purchases or ads), commercial practices, VAT registration, and developing the app in a professional capacity. A hobbyist with no plan to commercialise "may not be considered a trader". Apple also says that having "a legal status associated with a business activity" suggests trader status, individual or not (same page). Apple "can't determine" status for the developer.

### Can an individual account list a company's details? No.

- Individual: the personal legal name is the seller on the store. A sole proprietor must enrol as an individual ([Apple enrolment](https://developer.apple.com/help/account/membership/program-enrollment); [D-U-N-S page](https://developer.apple.com/help/account/membership/D-U-N-S)).
- Organisation: must be a legal entity (not a DBA, trade name or branch), with a D-U-N-S number, a website and a work email on the organisation's own domain. The legal entity name is the seller.
- I found no Apple page that lets an individual account show a company's name. This is my inference from the two rules above.

### What moving to a BV involves

| Step | Detail and source |
|---|---|
| Found the BV | Notary required. Notary fee €500 to €1,500 by the KvK's indication, €1,200 to €2,000 online by one provider; KvK registration €85.15 once; minimum share capital €0.01 ([DutchRegist](https://company-registration-netherlands.com/company-formation-cost-netherlands/), [KvK fee](https://www.kvk.nl/inschrijven/inschrijfvergoeding), [Holdwise](https://holdwise.nl/kennisbank/bv-oprichten-kosten-2026)). Can take days to a week ([Loyal Administratie](https://www.loyaladministratie.nl/kennisbank/bv-oprichten-den-haag-2026)). |
| D-U-N-S number | Free. Up to 5 business days from Dun & Bradstreet, then up to 2 business days to reach Apple ([Apple D-U-N-S page](https://developer.apple.com/help/account/membership/D-U-N-S); the 5-day figure is quoted by [getsetkeys](https://getsetkeys.com/guides/apple-developer-organization-enrollment-duns)). |
| Enrol as organisation | $99 a year. Needs a public website and a work email on the BV's domain. Apple gives no review time. One developer reported 11 hours ([UPTHOS](https://tools.upthos.com/en/guides/apple-developer-llc)); Apple may ask for notarised documents. |
| Move the app | App transfer needs a released version, no review in progress, and both accounts to have accepted the latest agreements. The transfer expires after 60 days if not accepted ([criteria](https://developer.apple.com/help/app-store-connect/transfer-an-app/app-transfer-criteria), [initiate](https://developer.apple.com/help/app-store-connect/transfer-an-app/initiate-an-app-transfer)). Starting under the BV from day one avoids the transfer. |
| Total time | My estimate: 2 to 4 weeks before the first submission. |
| Running cost | One small-BV guide puts it at €1,300 to €4,460 a year if Josh keeps the books and an office files the annual accounts, and €2,720 to €6,960 if everything is outsourced. The KvK charges nothing yearly ([mijnbv.nu](https://www.mijnbv.nu/kennisbank/artikelen/kosten-bv-per-jaar)). The state's own indication for bookkeeping is €600 to €1,800 ([DutchRegist, citing business.gov.nl](https://company-registration-netherlands.com/company-formation-cost-netherlands/)). |
| Owner salary rule | The same source lists a customary director salary of at least €58,000 for 2026. Whether it applies to a BV earning a few hundred euros needs an accountant. |

A BV is always a trader, so the store would show the BV's address. That address must be a real visit address at the KvK (below), so the home address is hidden only if the BV is registered at a virtual office.

### Which addresses the KvK accepts, and what it publishes

- Visit address (bezoekadres): where work is done and where the owner, directors or staff are regularly present. It must exist in the national address register. **A postbox is not allowed** ([coworkings.nl, summarising KvK](https://coworkings.nl/news/vestigingsadres-kvk-eisen-postbus-virtueel-kantoor); [Law & More](https://lawandmore.nl/onderneming-registreren-met-virtueel-adres); [Rabobank](https://www.rabobank.nl/bedrijven/eigen-bedrijf-starten/een-postbus-aanvragen-hoe-doe-je-dat)).
- Home address: accepted as the visit address if the owner works there. A virtual office counts only if it comes with a real workplace, access in opening hours and a landlord registered at the KvK for renting out office space. Occasional flex desks do not count (coworkings.nl). A "KvK registration address" service starts at €50 a month, or €40 on an annual contract, excluding VAT ([virtualoffice.nl](https://virtualoffice.nl/zakelijk-postadres)). Another comparison site quotes from €73 a month.
- Postal address (postadres): a postbox is allowed here.
- What the KvK publishes: the visit address is public by law, even when it is a home address. Home addresses of directors and other officers are not public (KvK default since 1 January 2022). Telephone numbers and the BSN are not public ([KvK privacy FAQ](https://www.kvk.nl/over-kvk/veelgestelde-vragen-over-privacy-en-het-handelsregister)).
- Shielding the visit address: **an eenmanszaak can always do it**, in Mijn KVK or at registration, but it must have a different public postal address that is not the home address. **A BV can do it only if there is a concrete danger** (a wish for privacy is not enough) ([KvK](https://www.kvk.nl/over-het-handelsregister/afschermen-van-je-bezoekadres-wat-is-mogelijk)). Shielded addresses stay visible to authorities, lawyers, notaries, bailiffs and banks ([Knab](https://bieb.knab.nl/ondernemen/priveadres-afschermen-kvk-dit-zijn-je-opties)).
- The KvK register has no link to the store page. Apple shows what an individual types in, or the D-U-N-S address for an organisation.

### Cheaper ways to keep the home address off the store page

| Route | Cost | Notes |
|---|---|---|
| Declare "not a trader" | €0 | Only if Rain is free with no ads or in-app purchases. Consumer-rights notice shown to EU buyers. Legal call is Josh's. Can be switched on per app later. |
| PriPost postbox (individual) | €6.55 a month plus €17.95 to €30.75 registration (Rabobank), or €27.50 (ikwordzzper), excluding VAT. About €100 first year. | Monthly cancellable; has private ("particulier") and business tariffs ([Rabobank](https://www.rabobank.nl/bedrijven/eigen-bedrijf-starten/een-postbus-aanvragen-hoe-doe-je-dat), [ikwordzzper](https://www.ikwordzzper.nl/zzp-kennisbank/diverse-algemene-onderwerpen/gebruik-maken-van-een-postbus), [PriPost tariffs](https://www.pripost.eu/postbox-tarieven/)). PriPost also says a postbox is enough as the public postal address when shielding an eenmanszaak's visit address ([PriPost](https://www.pripost.eu/postbox/postbus-alternatief)). |
| ALLSAFE postbox | €16.95 a month excluding VAT, 6-month minimum, private use allowed | [ALLSAFE](https://www.allsafe.nl/en/blog/how-much-does-a-po-box-cost-per-month) |
| PostNL postbus | €275 a year plus €47.50 to €50 start, excluding VAT | PostNL's page speaks of business customers ([PostNL](https://www.postnl.nl/zakelijk/klantenservice/producten-services/postbus/uitleg-aanvragen), [tariff booklet](https://www.postnl.nl/api/assets/blt43aa441bfc1e29f2/bltb5a50814dab40b01/tarievenboekje-juli-2026.pdf)). Dearest option. |

Not verified: whether Apple's reviewers accept a mail-forwarding service's address (as opposed to a PostNL postbus) as a "P.O. Box" with a bill as proof. I did not sign up for anything to test it. Also not verified: whether a postbox satisfies Article 30 of the DSA itself; Apple's page says it accepts one. The phone number is public too, so Josh needs a number that can receive a verification code and that he is happy to publish.

---

## 2. Hosting

### What ChatGPT Sites is

An OpenAI product, in public beta: you describe a website or lightweight app to ChatGPT or Codex, and OpenAI builds, hosts and shares it on a `chatgpt.site` address or a custom domain ([OpenAI help centre](https://help.openai.com/en/articles/20001339-creating-and-using-chatgpt-sites), [Sites docs](https://developers.openai.com/codex/sites), [Sites terms](https://openai.com/policies/chatgpt-sites-terms)). Not on Free or Go plans; available on Plus, Pro, Business and Enterprise.

### Can it do Rain's job? No.

| Need | What the docs say |
|---|---|
| Run Python with h5py and numpy | The docs name the scope as "static sites to full-stack JavaScript or TypeScript web apps" ([OpenAI use case](https://developers.openai.com/codex/use-cases/build-and-deploy-internal-apps)). No page mentions Python or native libraries. The storage products are D1 and R2, which are Cloudflare products, so the runtime is probably a Workers-style one (my inference; OpenAI does not say). |
| Run a job every five minutes | Sites has "Automations": a cloud schedule that holds "task instructions and timing" for recurring work on a site, created and reviewed in ChatGPT ([help centre](https://help.openai.com/en/articles/20001339-creating-and-using-chatgpt-sites)). These are ChatGPT tasks, not a cron trigger for your own code. The docs also say "background services" may be unsupported. |
| Keep a secret | Yes. Hosted environment variables and secrets are set in the site's settings ([manage a site](https://developers.openai.com/codex/sites/managing-a-site)). |
| Serve small static files | Yes, in principle: HTTP, HTTPS and WebSockets; file storage on R2 has no fixed limit ([Sites docs](https://developers.openai.com/codex/sites)). |

### Price and terms

- Hosting is free through 31 December 2026. From 1 January 2027 OpenAI meters it. Plus includes 125 hosting credits a month, Pro 375 ([Sites docs](https://learn.chatgpt.com/docs/sites)).
- Proposed rates: 16 credits per 100,000 requests, 25 a month for a site with storage, 25 a month for a custom domain. Rain's 6 million requests a month would use about 960 credits (6M ÷ 100,000 × 16), more than a Plus or Pro allowance, before the storage and domain fees. A credit's price in euros is not published: "Credit purchase prices ... depend on your plan".
- Plus costs $20 a month ([third-party summary of OpenAI pricing](https://convika.com/compare/chatgpt-sites-alternatives/)). I did not check OpenAI's pricing page directly.
- Terms: a beta service. OpenAI "reserve[s] the right to delete, remove, unpublish, or otherwise disable your ChatGPT Site, at any time for any reason". Josh indemnifies OpenAI for claims about the site. Commercial use is not banned; sales must go through a third-party payment provider ([Sites terms](https://openai.com/policies/chatgpt-sites-terms)).
- Launch would fall straight after the free period ends, with an unpublished credit price.

### Cheapest host that fits

**AWS (recommended).** Josh's website and OpenTofu code are already there (LAUNCH.md).

| Part | Price | Source |
|---|---|---|
| Schedule: EventBridge Scheduler, every 5 minutes (8,640 runs a month) | Free up to 14 million invocations a month | [EventBridge pricing](https://aws.amazon.com/eventbridge/pricing) |
| Lambda running Python | Free up to 1 million requests and 400,000 GB-seconds a month. At 1 GB for 10 seconds a run, Rain uses about 86,400 GB-seconds (my estimate of run time). | [Lambda pricing](https://aws.amazon.com/lambda/pricing/) |
| Python libraries | A .zip may be 250 MB unzipped; container images up to 10 GB. numpy and h5py should fit (my estimate). | [Lambda quotas](https://docs.aws.amazon.com/lambda/latest/dg/gettingstarted-limits.html) |
| Secret (KNMI key) | Parameter Store standard SecureString: no charge. Secrets Manager: $0.40 a month if wanted. | [Systems Manager pricing](https://aws.amazon.com/systems-manager/pricing/), [Secrets Manager pricing](https://aws.amazon.com/secrets-manager/pricing/) |
| S3 writes | $0.005 per 1,000 PUTs in us-east-1 ($0.0053 in Paris). 20 tiles every 5 minutes is 172,800 PUTs, about $0.90 a month; 100 tiles is about $4.60. Tile count is my assumption. | [S3 pricing summary](https://getcostiq.com/pricing/aws-s3), [S3 in Paris](https://mathieukerbel.com/blog/aws-s3) |
| CloudFront | Always-free tier: 1 TB out and 10 million requests a month. Rain's 6 million requests and 30 to 60 GB (global-data.md) fit. The free tier is shared with Josh's existing site. | [CloudFront pricing](https://aws.amazon.com/cloudfront/pricing/pay-as-you-go/) |
| **Total** | **About $0 to $5 a month**, mostly S3 writes | |

**Cloudflare (fallback).** Workers Free allows 10 ms of CPU per invocation, too little for decoding, so the Workers Paid plan at $5 a month is the minimum. It allows 30 seconds of CPU per cron run for jobs under an hour, 128 MB of memory, 10 million requests included, and Cron Triggers ([pricing](https://developers.cloudflare.com/workers/platform/pricing), [limits](https://developers.cloudflare.com/workers/platform/limits)). R2 storage is free up to 10 GB, 1 million writes and 10 million reads a month, with free egress ([R2 pricing](https://developers.cloudflare.com/r2/pricing)). Python Workers are generally available and Pyodide ships h5py 3.13.0 ([Cloudflare blog](https://blog.cloudflare.com/python-workers-ga), [Pyodide packages](https://pyodide.org/en/stable/usage/packages-in-pyodide.html)), but I did not test decoding KNMI's file in WebAssembly. About $5 a month plus that risk.

The €5 to €20 a month in `global-data.md` and LAUNCH.md was unchecked; this replaces it.

---

## Not checked

- Whether Apple accepts a mail-forwarding address in place of a PostNL postbus.
- PriPost's current private tariff (two sources give different registration fees).
- Whether the €58,000 salary rule bites a BV that earns almost nothing.
- Credit price for ChatGPT Sites overage.
- Real run time and tile count of the Rain job; the AWS figures use my assumptions above.
