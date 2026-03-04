cd ios/
rm -f Podfile.lock
rm -rf Pods/
pod repo update
cd ..

cd macos/
rm -f Podfile.lock
rm -rf Pods/
pod repo update
cd ..

flutter clean
flutter pub get