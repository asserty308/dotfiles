if [ -d "ios" ]; then
	cd ios/
	rm -f Podfile.lock
	rm -rf Pods/
	pod repo update
	cd ..
fi

if [ -d "macos" ]; then
	cd macos/
	rm -f Podfile.lock
	rm -rf Pods/
	pod repo update
	cd ..
fi

flutter clean
flutter pub get