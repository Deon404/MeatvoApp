# Quick startup

Full guide (backend + web + Flutter testing): **[docs/LOCAL_DEV_AND_FLUTTER_TESTING.md](docs/LOCAL_DEV_AND_FLUTTER_TESTING.md)**

## Fast commands

```powershell
# Backend
cd backend
npm install
npm run dev

# Flutter (configure old_meatvo/.env first)
cd old_meatvo
flutter pub get
flutter run
```

- API: http://localhost:8080/api  
- Admin: http://localhost:8080/admin  
- Android emulator API URL: `MEATVO_API_ROOT=http://10.0.2.2:8080`
