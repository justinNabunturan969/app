# PUP-ITech Borrowing

## Run locally

The app opens a setup screen when backend credentials have not been supplied.
To use authentication and data features, run it with your Supabase project
values (Project Settings → API):

```powershell
flutter run `
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co `
  --dart-define=SUPABASE_ANON_KEY=YOUR_ANON_KEY
```

Do not commit these values to source control.
