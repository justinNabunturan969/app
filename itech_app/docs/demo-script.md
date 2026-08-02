# PUP-ITech Borrowing — Live Demo Script

A guided happy-path walkthrough for the thesis defense. Total time: **~6 minutes**
(adjust to taste). Read the italicised stage directions softly under your
breath; speak the regular text out loud.

> **Tip:** open this file on a second screen or print it. Don't read it
> word-for-word — internalise the beats, then improvise the words.

---

## 0. Pre-demo checklist (do this 5 minutes before you go on)

- [ ] App is on the **Home** tab, **light mode**, freshly opened
- [ ] Demo data is "alive": one borrowing due in ~10 min, one overdue,
      one freshly returned, a couple of unread notifications
- [ ] Browser tab is full-screen / projector is showing the app only
- [ ] DevTools closed, no notifications, phone face-down
- [ ] Second screen (your laptop) has this script + the Design System
      doc open in case you need to bail out

If something looks off, hit the browser refresh — the mock data resets
relative to *now* every time the app boots.

---

## 1. Opening — *"Why this app exists"*  (0:00 – 0:30)

**What to do:** Land on the Home tab. Stand still for a beat.

> *"The PUP Institute of Technology loans out equipment — multimeters,
> oscilloscopes, microcontrollers — to engineering students for lab work.
> Right now the entire process is paper-based. Students line up at the
> equipment office, fill out a form, and hope the thing they need is
> actually on the shelf. This app replaces the form with a phone, and
> the hope with real-time availability."*

**Beat:** let the panel look at the Home screen for 2–3 seconds. The
staggered entrance has already finished; the screen is calm.

---

## 2. Home tab — *"Finding equipment"*  (0:30 – 1:30)

**What to do:** Point at the greeting, then the quick-stats row, then
the search bar.

> *"The Home tab is a student's first stop. It greets them by time of
> day — good morning, Juan — and shows a quick read on where they stand:
> how many things they have out, what's pending, and what's overdue. From
> here they can search the catalogue, filter by category, or just scroll
> the grid."*

**Beat (1:00):** Tap the **voice-search** mic icon. Speak clearly:
*"multimeter."* The overlay transcribes, drops you into the filtered
results.

> *"The whole flow is built around the moment of need — I'm in the lab,
> I need a multimeter, where is it?"*

**Beat (1:20):** Tap any equipment card. *(Nothing dramatic happens yet
in this build, but it shows the cards are interactive and the icon
swaps to a lock when something is borrowed — that visual feedback is
what tells the student 'come back later.')*

---

## 3. Borrowings tab — *"Live state"*  (1:30 – 2:45)

**What to do:** Tap the **Borrowings** tab in the bottom nav.

> *"Borrowings is the part the panel will remember. Watch what happens
> when we land here —"*

**Beat (1:40):** Let the staggered card entrance play out. *Don't talk
over it.* The cards "fly in" top to bottom.

> *"Every card is a real loan. The cyan card on top is the Fluke 87V
> multimeter — I borrowed it six hours ago, it's due in about ten
> minutes. Watch the countdown."*

**Beat (1:55):** Point at the countdown text. Wait two seconds. It
ticks from "9m 58s" to "9m 57s" to "9m 56s".

> *"That's not a video loop. That's a real countdown, recomputed every
> second from a controller-level ticker. The same controller drives
> every other tab — the Profile's Active count, the Analytics page's
> on-time rate, the notification badge in the nav."*

**Beat (2:10):** Tap the **Overdue** filter chip. One card lights up
red.

> *"This one — the Arduino — was due five hours ago. The card tints red,
> the progress bar fills, the countdown becomes 'Overdue by 5h 7m'."*

**Beat (2:25):** Tap the red **Return Now** button. The confirm dialog
appears. Confirm.

> *"Confirming moves the item from active to history, and live, you'll
> see the count drop, the card disappear, the History tab fill. Try it."*

**Beat (2:35):** Tap the **History** filter chip. Show the freshly
returned item at the top with a green "Returned" pill.

---

## 4. Analytics tab — *"The story in numbers"*  (2:45 – 4:00)

**What to do:** Tap the **Analytics** tab.

> *"Borrowings is the day-to-day. Analytics is the bigger picture —
> what has this student actually been doing all semester?"*

**Beat (2:55):** Point at the three metric cards at the top (Total
Borrowed, Active Borrowings, On-Time Rate).

> *"Twenty-four total loans. Three active right now. And a 92% on-time
> return rate — which, candidly, is the number the equipment office
> actually cares about."*

**Beat (3:10):** Scroll down to the **Weekly Activity** chart.

> *"Last seven weeks. Notice the bar that hits six — that's this week,
> with the active loans you're looking at on the Borrowings tab. The
> bar above four was midterms, two weeks ago. You can see the rhythm of
> the semester in this chart."*

**Beat (3:25):** Scroll further — **Most Borrowed Items**, **Category
Breakdown**, **Achievements**.

> *"The most-borrowed list is what tells us what to buy more of. The
> category breakdown tells us which rooms are under-served. And the
> achievements — the student gets one every time they cross a threshold.
> It's gamified, but quietly."*

---

## 5. Profile tab — *"Identity and trust"*  (4:00 – 4:45)

**What to do:** Tap the **Profile** tab.

> *"Profile is where the app earns trust. The student's real ID, their
> programme, their year and section, when they joined — all there. The
> PUP badge isn't decoration, it's an institutional marker. Students
> know this is the official app, not some side project."*

**Beat (4:15):** Scroll to the **Achievements** section.

> *"Five achievements, three unlocked, two still locked — including
> 'Overdue-Free', which is currently locked because of that Arduino. The
> moment they return it, this row unlocks. That's the loop."*

**Beat (4:25):** Scroll to **Preferences**. Toggle **Haptic Feedback**
off and on (it vibrates on toggle — fun moment).

> *"Every interactive surface has haptic feedback. It's a small thing
> but it makes the app feel real instead of web-y."*

**Beat (4:35):** Tap **Design System** in the Support section.

---

## 6. Design System page — *"One more thing"*  (4:45 – 5:30)

**What to do:** You're now on the Design System page.

> *"I want to show you one more thing, and this is the part the panel
> usually doesn't expect. Every screen you've seen is built from a
> single set of design tokens — nine colors, four type sizes, three
> components. This page is the tokens, live, in the app."*

**Beat (4:55):** Scroll slowly through Colors → Typography → Components
→ Surfaces.

> *"Notice everything is in the same vocabulary. The icon chip on this
> page is the same icon chip on the Home tab. The status pill here is
> the same status pill on the Borrowings tab. One system, one source
> of truth."*

**Beat (5:10):** Toggle the theme using the button in the top right.

> *"And one more thing — every token has a light and dark variant.
> This is the same page, the same components, just in dark mode. The
> glow, the contrast, the readability — all engineered for both."*

**Beat (5:20):** Hit the back arrow to return to Profile.

---

## 7. Notifications tab — *"Closing the loop"*  (5:30 – 6:00)

**What to do:** Tap the **Notifications** tab in the bottom nav.

> *"Last tab. Notifications. Every action the system takes on a
> student's behalf — request approved, item due, item overdue, new gear
> on the shelf — surfaces here. Type-colored, grouped by what they
> mean, swipe to delete with undo. The badge in the nav tells the
> student there's something waiting for them."*

**Beat (5:40):** Swipe-left on any notification to reveal the red
**Delete** background, then complete the swipe. A snackbar appears with
an **Undo** action. Tap Undo.

> *"And if they delete by mistake, undo brings it right back."*

**Beat (5:50):** Tap **Mark all read**. The amber badge drops to zero,
the "3 unread" line flips to mint-green "All caught up".

> *"That's the full loop. Find equipment, borrow it, watch the
> countdown, get a reminder, return it, see your stats, get a badge.
> And every screen is the same design system."*

---

## 8. Closing line

> *"The thesis, in one sentence: a real-time, design-system-driven
> replacement for the paper equipment-borrowing workflow at PUP-ITech.
> Five tabs, one controller, one set of tokens, and a live demo
> every time."*

**Beat:** Stop. Let the panel ask questions.

---

## Bail-out phrases

- *"Let me jump to the part I was most excited about —"*  → go to the
  Borrowings tab
- *"I think the design system page is the strongest part of the
  work —"*  → Profile → Design System
- *"The live countdown is the bit that surprises people —"*  → show
  the timer ticking, then return
- *"Sorry, let me back up —"*  → tap back, or restart the app
