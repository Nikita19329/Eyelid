.PHONY: app debug run test icon clean

app:
	./scripts/build-app.sh release

debug:
	./scripts/build-app.sh debug

run: app
	-pkill -x Eyelid
	@while pgrep -x Eyelid >/dev/null; do sleep 0.1; done
	@# -n: Launch Services may still list the old instance for a moment and fail with error -600.
	open -n build/Eyelid.app

test:
	swift test

icon:
	./scripts/make-icon.sh

clean:
	rm -rf .build build
