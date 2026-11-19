munged: ../munged/.patched

../munged/.patched: $(shell find ../src -type f -name '*.sol') applyMunging.patch
	@rm -rf ../munged
	@cp -r ../src ../munged
	@patch -p0 -d ../munged < applyMunging.patch
	@touch $@

record:
	diff -ruN --exclude=.patched ../src ../munged | sed -E 's,\.\./src/|\.\./munged/,,g' | sed -E 's,((\-\-\-|\+\+\+) [^[:space:]]*).*,\1,' > applyMunging.patch

clean:
	rm -rf ../munged

.PHONY: clean record munged # Keep the completion marker non-phony to protect munged edits.
