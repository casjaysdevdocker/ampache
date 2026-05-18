# TODO — ampache migration

Living list of what still needs doing. Remove items only when actually complete.

## Completed this pass

- [x] `Dockerfile` — updated `BUILD_DATE` to `202605131434`; prerequisites RUN changed to `true`; "Creating and editing system files" block stripped of inline APK repos management
- [x] `.env.scripts` — migrated to canonical 2026 header; all repo-specific values preserved
- [x] `CLAUDE.md` — replaced full TEMPLATE.md content with minimal per-repo pointer
- [x] `IDEA.md` — created: one-paragraph description of the image
- [x] `AI.md` — created: comprehensive technical description of how the image is built and wired
- [x] `README.md` — replaced old dockermgr-style README with user-facing docs (what it is, docker run, docker-compose, env vars table, volumes table, ports table)
- [x] `rootfs/usr/local/bin/entrypoint.sh` — copied from example; updated `CONTAINER_NAME` and description to `ampache`
- [x] `rootfs/usr/local/bin/pkmgr` — copied verbatim from example
- [x] `rootfs/usr/local/etc/docker/functions/entrypoint.sh` — copied verbatim from example
- [x] `rootfs/root/docker/setup/00-init.sh` — copied from example (canonical 2026 header)
- [x] `rootfs/root/docker/setup/01-system.sh` — copied from example (stub)
- [x] `rootfs/root/docker/setup/02-packages.sh` — copied from example (stub)
- [x] `rootfs/root/docker/setup/03-files.sh` — copied from example (canonical header)
- [x] `rootfs/root/docker/setup/06-post.sh` — copied from example (stub)
- [x] `rootfs/root/docker/setup/07-cleanup.sh` — copied from example (stub)
- [x] `rootfs/root/docker/setup/04-users.sh` — preserved (service-specific apache/mysql user creation)
- [x] `rootfs/root/docker/setup/05-custom.sh` — preserved (wipe-and-replace + Ampache zip download)
- [x] `rootfs/usr/local/etc/docker/init.d/09-mariadb.sh` — updated to canonical pattern (ERR trap handler, `__trap_err_handler`, canonical header, `SERVICE_USES_PID`)
- [x] `rootfs/usr/local/etc/docker/init.d/99-ampache.sh` — updated to canonical pattern (same as above)

## Outstanding

- [ ] Build verification — run `buildx` against the repo and confirm the image builds clean with all packages installable
- [ ] Runtime smoke test — start the container, verify MariaDB starts and the Ampache installer loads at `http://localhost:80/`
- [ ] `PLAN.md` — update `BUILD_DATE` field and mark completed steps; currently has stale 202503 date
- [ ] Confirm Ampache version in `05-custom.sh` — `ampache-7.9.3_all_php8.4.zip` was current at time of writing; bump when a new release is available
- [ ] SSL config — verify `/config/enable/ssl` toggle works with the Apache vhost in `conf.d/ampache.conf`
- [ ] `template-files/config/` seeding — verify all three config trees (apache2, php84, my.cnf.d) are correctly staged under `rootfs/usr/local/share/template-files/config/` by `05-custom.sh`
