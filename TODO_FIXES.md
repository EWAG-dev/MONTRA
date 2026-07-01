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
15. Rematch makes me recreate an account because quiz always ends in create an account. even if you are already signed (still brings you to that screen as if you were not signed in) or click “already have an account. sign in” (this button does nothing, brings up an “please enter email and password” red error.

---

## Copilot Status Commentary (July 1, 2026)

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
- Full dispute lifecycle policy/state machine still pending product decision.

7. 3 strikes and shutdown warning: ⬜ Todo
- Blocked pending explicit strike policy rules (captured in HUMAN_TASKS.md).

8. Notifications close + dynamic badge/count: ✅ Complete
- Close action added; dot now reflects unread count and hides at zero.

9. Client tutorial walkthrough too barren: ✅ Complete
- Walkthrough expanded to richer multi-page guidance with concrete bullet actions.

10. Remove quiz top-right X: ✅ Complete

11. Remove hand-wave emoji: ✅ Complete

12. Support vs MONTRA Team naming: ✅ Complete
- Unified as MONTRA Support Team in app messaging UI.

13. Orientation links still on Google Drive: ⬜ Todo
- Waiting on final replacement URLs from you (tracked in HUMAN_TASKS.md).

14. Improve client verification email quality/deliverability: 🟡 Partial
- Verification UX is now improved: branded button email + simplified in-app "I've verified my account" flow are implemented.
- Remaining work is deliverability configuration (SPF/DKIM/DMARC + sender domain alignment) tracked in HUMAN_TASKS.md.

15. Rematch/account recreation/sign-in dead-end: ✅ Complete
- Existing-account action now routes back to login instead of dead-end inline sign-in behavior.