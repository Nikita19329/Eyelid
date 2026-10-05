.PHONY: app debug run clean

app:
	./scripts/build-app.sh release

debug:
	./scripts/build-app.sh debug

run: app
	-pkill -x Eyelid
	@while pgrep -x Eyelid >/dev/null; do sleep 0.1; done
	open build/Eyelid.app

clean:
	rm -rf .build build
