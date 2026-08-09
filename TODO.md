# TODO - PUP-ITech Analytics Dashboard (Replace Search Tab)

## Step 1: Add Analytics tab to bottom nav
- [x] Locate StudentShell bottom navigation
- [ ] Replace Search tab with Analytics tab (index 1)
- [ ] Ensure AppBar/back behavior remains consistent

## Step 2: Create analytics feature folder
- [ ] Create `lib/features/analytics/analytics_page.dart`
- [ ] Create widgets:
  - [ ] `lib/features/analytics/widgets/stat_card.dart`
  - [ ] `lib/features/analytics/widgets/bar_chart.dart`
  - [ ] `lib/features/analytics/widgets/progress_list.dart`
  - [ ] `lib/features/analytics/widgets/achievement_badge.dart`
- [ ] Create `lib/features/analytics/data/mock_data.dart`

## Step 3: Implement Analytics page UI
- [ ] Build page layout matching prompt + Home style
- [ ] 3 quick stats cards with count-up animation (300ms)
- [ ] Monthly Activity animated horizontal bar chart (500ms)
- [ ] Most Borrowed Items top 5 with animated progress bars
- [ ] Category Breakdown percent bars with distinct colors
- [ ] Achievements/Badges with check + lock icons
- [ ] Amber-style Share Stats + Export Data buttons

## Step 4: Animations & interactions
- [ ] Card tap scale (200ms) + haptic feedback on taps
- [ ] Page load staggered fade-in

## Step 5: Wire navigation
- [ ] Update StudentShell `_pageForIndex` to return Analytics page for index 1
- [ ] Ensure imports compile

## Step 6: Validate
- [ ] Run `flutter analyze`
- [ ] Run app and verify tab switch and animations

