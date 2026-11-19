# Updating this package

There is no `update.sh` here on purpose. This file is a **re-export** of
`inputs.content-extractor.packages.<system>.dsh`, so it pins no version and no
hash of its own — the upstream flake builds both halves (the `extractor-abi` C
library and the DSH host that installs it at `native/libextractor.so`) and they
cannot drift apart.

To pick up a new upstream release:

```sh
nix flake lock --update-input content-extractor
nix build .#dsh-content-extractor      # verify before committing the lock
```

The previous `update.sh` belonged to the old standalone recipe: it read tags
from a separate `dsh-video-fetch` repository and rewrote an `npmDepsHash` that a
re-export does not have. Both are gone, so keeping the script would only produce
a confusing failure. `bas-remote`, the other re-export in this group, has no
update script either.
