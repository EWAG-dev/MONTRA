# MONTRA Admin Guide

Internal tools for the MONTRA/EHF team. Not linked from the public site.

## Coach Verification (trust-stack badges)

The **ID Verified**, **Background Checked**, and **MONTRA Certified™** badges on a
coach's public profile only appear when an admin has explicitly turned them on for
that coach. They are off by default so the platform never claims a check it didn't
actually perform. (Insurance Verified and CPR/AED come from fields the trainer
provides during onboarding and are shown automatically when present.)

### Using the admin page

1. Go to **https://montra-27532.web.app/admin.html** (or `/admin.html` on whatever
   host the site is deployed to). The page is `noindex` and not linked anywhere.
2. **Sign in** with a MONTRA admin account — i.e. an account whose email is in the
   backend's `ADMIN_EMAILS`, or that has an `admin` / `trainer_admin` custom claim.
   A non-admin sign-in loads but every action returns "not an admin."
3. You'll see every coach with three toggles. **Only flip a badge on after the real
   check has actually cleared:**
   - **ID Verified** — government ID confirmed.
   - **Background Checked** — background-check vendor returned clear.
   - **MONTRA Certified™** — coach completed MONTRA's certification/vetting.
4. Each toggle **saves immediately** (a toast confirms). Flip it back off to revoke.
5. Use the **search** box to find a coach by name or email; **Refresh** re-pulls the
   list; the top counters show how many coaches are fully verified vs. missing a badge.

The profile badge updates as soon as the coach's page is reloaded.

### What it calls (for reference / scripting)

- Lists coaches: `GET /api/admin/trainer-applications` (admin auth).
- Sets a flag: `POST /api/admin/trainers/:id/verification` with a JSON body of any of
  `{ "idVerified": true, "backgroundCheckCleared": true, "montraCertified": true }`
  (admin auth). 400 if no boolean flag is provided, 404 if the coach id is unknown.

To wire an automated vetting vendor, have it call that POST endpoint with the cleared
flags when a check passes — no UI needed.

> Security note: these three flags are **only** settable through this admin endpoint.
> A trainer cannot set them on themselves via the apply/onboarding flow (the backend
> ignores them from that input), so the badges can't be self-claimed.
