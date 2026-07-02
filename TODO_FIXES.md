# Bugfixes to do before launch

App
1. Debug chat: Messages sent by client go both into client’s chat bubble and trainer’s chat bubble. (Screenshot)
2. Startup behavior for trainer: signing agreement and the orientation videos is one-and-done. make sure the agreement they sign is present in settings afterwards.
And for client, they shouldn’t have the quiz over and over.
3. Personal Info in profile does not get filled out by account creation, but it should be.
4. Gift a session (coming soon), refer a friend (mostly works, but you don’t get pioints yet)
5. settings montra ai preview what is that? get rid of it.
6. Trainer needs to be able to confirm that a session was completed and log workouts. that’s what keeps clients stats up to date
And we want client to fill out a survey at some point. And we want to make it easy to complain about the client. If trainer says session is done but client says no one ever came… 
7. TRAINER ONLY GETS 3 STRIKES AND THEY NOTICE ACCOUNT IS BEING SHUT DOWN
8. Notifications can’t be closed. also is not dynamic (it always shows a dot, even when there’s no notification). should show number of notifications as well)
9. After signup, tutorial walkthrough for client is very barren (screenshot in Taylor’s mac’s notepad)
10. Take away the “x” from top-right of quiz because we want them to finish the quiz and match with a trainer. the ywill never see quiz again unless they click rematch.
11. remove hand-wave emoji
12. support vs montra team. what did luis ask for. can we just combine and call montra support team.
13. Fix the coach orientation video links that ucrrently go to google drive: ✅ Done
- Orientation videos now open and play inside the app instead of bouncing out to the browser.
14. Improve the email for client account verification. currently you have to actually highlight the link. also it goes to spam and the coach one seems not to?

Verification deliverability runbook (current progress: Step 1 and Step 2 complete, currently on Step 3)
1. ✅ Railway variables set
- `RESEND_API_KEY`
- `FROM_EMAIL=MONTRA <noreply@montrafit.com>`
- `WEBSITE_URL` set to current live site URL
- Optional but recommended: `CLIENT_VERIFY_CONTINUE_URL` set to final verify landing URL

2. ✅ Resend domain verified
- Sending domain is verified in Resend and ready for authenticated sending.

3. DNS alignment in GoDaddy (in progress)
- Add all SPF and DKIM records shown by Resend exactly as provided.
- Ensure only one SPF TXT exists at root. If one already exists, merge includes into a single `v=spf1 ... ~all` record.
- Add DMARC TXT for host `_dmarc` with value:
`v=DMARC1; p=none; adkim=s; aspf=s; rua=mailto:dmarc@montrafit.com; fo=1; pct=100`
- Save changes and wait for DNS propagation.

4. Provider-side verification
- In Resend, confirm domain status remains Verified after DNS settles.
- Confirm SPF and DKIM both show pass/healthy in the domain panel.

5. End-to-end app flow test
- From iOS onboarding, tap resend verification email.
- Open the received email and tap Verify My Account.
- Return to app and tap I've verified my account.
- Confirm onboarding proceeds without verification error.

6. Inbox placement + auth checks
- Test Gmail, Outlook, and iCloud inboxes.
- Confirm delivery lands in Inbox (not spam/junk).
- In message headers, confirm: SPF=pass, DKIM=pass, DMARC=pass.

7. Tighten DMARC after stable delivery
- After a few days of clean reports, change DMARC policy from `p=none` to `p=quarantine`, then optionally `p=reject`.

Definition of Done for item 14
- Verification email CTA works end-to-end in app.
- Sender auth passes (SPF/DKIM/DMARC) for major providers.
- Inbox placement is acceptable for Gmail, Outlook, iCloud.
- DMARC monitoring policy is active and scheduled for tightening.
15. Rematch makes me recreate an account because quiz always ends in create an account. even if you are already signed (still brings you to that screen as if you were not signed in) or click “already have an account. sign in” (this button does nothing, brings up an “please enter email and password” red error.

---

## Copilot Status Commentary (July 1, 2026)

Overall snapshot:
- ✅ Complete: 11
- 🟡 Partial: 3
- ⬜ Todo: 1

1. Chat bubble role bug: ✅ Complete
- Backend sender-role resolution updated to derive role from conversation ownership.

2. Trainer one-and-done gates + agreement visibility + client quiz repeat: ✅ Complete
- Trainer agreement/orientation persist and agreement is viewable from settings.
- Client onboarding routing now avoids repeated forced quiz when already matched.

3. Personal Info autofill: ✅ Complete
- Profile fields now seed from authenticated account info when local fields are empty.

4. Gift session + refer points: 🟡 Partial
- Refer flow now awards points (simple local points model).
- Gift a session still intentionally "coming soon" and not fully productized.

5. Remove settings MONTRA AI preview: ✅ Complete

6. Trainer complete + workout logging + client survey + complaint/report flow: 🟡 Partial
- Trainer can mark complete with workout notes from app.
- Client review flow now includes survey-style experience input.
- Trainer can file session issue reports (backend + app sheet).
- Dispute policy is now defined in HUMAN_TASKS.md; backend state machine implementation is next.

7. 3 strikes and shutdown warning: ⬜ Todo
- Policy rules are now defined in HUMAN_TASKS.md; backend/app enforcement implementation is next.

8. Notifications close + dynamic badge/count: ✅ Complete
- Close action added; dot now reflects unread count and hides at zero.

9. Client tutorial walkthrough too barren: ✅ Complete
- Walkthrough expanded to richer multi-page guidance with concrete bullet actions.

10. Remove quiz top-right X: ✅ Complete

11. Remove hand-wave emoji: ✅ Complete

12. Support vs MONTRA Team naming: ✅ Complete
- Unified as MONTRA Support Team in app messaging UI.

13. Orientation links still on Google Drive: ✅ Complete
- All orientation videos are now Firebase Hosting URLs and play in-app via native full-screen player.
- 6-video sequence is mapped and live under `/orientation/*`.

14. Improve client verification email quality/deliverability: 🟡 Partial
- Verification UX is now improved: branded button email + simplified in-app "I've verified my account" flow are implemented.
- Railway variables and Resend domain verification are complete.
- Current step is DNS alignment and final inbox/auth verification (SPF/DKIM/DMARC passes on Gmail, Outlook, iCloud).

15. Rematch/account recreation/sign-in dead-end: ✅ Complete
- Existing-account action now routes back to login instead of dead-end inline sign-in behavior.