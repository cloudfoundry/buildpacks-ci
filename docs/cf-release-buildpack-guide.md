# Releasing java-buildpack to Cloud Foundry

This guide walks through cutting a java-buildpack release and getting it into a
Cloud Foundry BOSH release, using 5.0.6 as the worked example. It is aimed at
someone doing this for the first time. Everything here is done by clicking in the
Concourse web UI.

The focus is the [cf-release](../pipelines/cf-release) pipeline -- the part that
wraps a shipped buildpack into a BOSH release, tests it, and publishes it. The
`java-buildpack` pipeline that produces the buildpack itself is only summarised
here; see `buildpack-release-pipeline-overview.md` for that side in detail.

Other buildpacks follow the same process; substitute the name throughout.

## Overview

A release crosses two pipelines:

1. **`java-buildpack`** builds and ships the buildpack, producing a GitHub
   release tagged `v5.0.6`.
2. **`cf-release`** wraps it in a BOSH release, deploys a CF environment, runs
   CATS against it, and publishes the finalized BOSH release.

```
java-buildpack pipeline             cf-release pipeline
-----------------------             -------------------
specs-switchblade-cflinuxfs4/5      [test]    trigger-buildpack-pipeline
   -> detect-new-version                        -> create-java-buildpack-dev-release
   -> ship-it                                   -> deploy -> cats
   -> GitHub release v5.0.6         [ship-it] ship-it            (bosh RC)
                                    [publish] update-java-buildpack-release-trigger
                                              -> publish-java-buildpack-release
                                                    -> bosh.io
```

The `cf-release` pipeline is organised into three groups: `test`, `ship-it`, and
`publish`.

For reference, the pipeline is defined in `pipelines/cf-release/cf-release.yml`
and its tasks live in [tasks/cf-release](../tasks/cf-release), but you do not
need to touch either to cut a release.

---

## Shipping the buildpack

This half is covered in depth by `buildpack-release-pipeline-overview.md`. In
short:

1. **Wait for the switchblade specs.** `specs-switchblade-docker-cflinuxfs4` and
   `specs-switchblade-docker-cflinuxfs5` take about 55 minutes each. They gate
   artifact building, and so gate the release: `detect-new-version-and-upload-artifacts`
   only accepts a buildpack that passed both.

2. **Check the long integration test by hand.**
   `create-cf-infrastructure-and-execute-integration-test-for-java` stands up real
   CF infrastructure and runs the integration suite. It takes **5 to 12 hours**.
   It runs on a parallel branch and is not a gate: no other job consumes it, so
   the release does not wait on it.

   It is therefore a manual check. Look at its latest build and only continue if
   it succeeded for the version you are shipping.

3. **Run `ship-it`** on the `java-buildpack` pipeline, then confirm the GitHub
   release `v5.0.6` at
   `https://github.com/cloudfoundry/java-buildpack/releases/tag/v5.0.6`.

---

## Building and testing the BOSH release

These jobs are in the `test` group of `cf-release`.

1. **Expect the previous version at first.** Until the steps below run, the
   release candidate still shows the previous version (5.0.5). No RC exists for
   5.0.6 yet, so pressing `ship-it` now would pick up the old one. This is a
   matter of ordering, not a permanent blocker.

2. **Run `trigger-buildpack-pipeline`.** Press `+` on the job. This produces a
   release commit in
   [java-buildpack-release](https://github.com/cloudfoundry/java-buildpack-release).

3. **Wait for the dev release and deploy.** `create-java-buildpack-dev-release`
   ([task](../tasks/cf-release/create-buildpack-dev-release)) builds the candidate
   BOSH release and uploads it to `bosh-release-candidates/`. The `deploy` job
   then deploys a CF environment against it. Expect `deploy` to take about an
   hour.

4. **Check CATS.** The `cats` job runs the
   [CF Acceptance Tests](https://github.com/cloudfoundry/cf-acceptance-tests)
   against that deployment, taking roughly 20 minutes. It must succeed before you
   can ship.

Budget about 1.5 hours between pressing `trigger-buildpack-pipeline` and being
able to press `ship-it`. This is the slow part of a release; everything after
`ship-it` takes minutes.

---

## Shipping and publishing the BOSH release

1. **Run `ship-it`.** Once CATS is green and an RC for 5.0.6 exists, press `+` on
   the `ship-it` job. This job is always manual; it is never triggered
   automatically. It picks up the latest successful CATS run, so if another CATS
   run starts before you press, it takes that one instead.

2. **Publish runs on its own.** There is no second button. A few minutes after
   `ship-it`, `update-java-buildpack-release-trigger` and then
   `publish-java-buildpack-release` fire automatically as `system`. The publish
   job ([task](../tasks/cf-release/finalize-buildpack-release)) finalizes the
   release, tags the `java-buildpack-release` repository, and cuts a GitHub
   release.

   If publish never ran, the cause is almost always that `ship-it` was not
   pressed. It is rarely a publish failure.

3. **Confirm it is out.** The finalized release appears on
   [bosh.io](https://bosh.io/releases/github.com/cloudfoundry/java-buildpack-release?all=1)
   within minutes of the publish job succeeding. Once it is listed there,
   external pipelines can consume it and the release is done.

Each release ships two stack variants: `java_buildpack-cflinuxfs4-v5.0.6.zip` and
`java_buildpack-cflinuxfs5-v5.0.6.zip`.

---

## `ship-it` is shared across all buildpacks

There is no per-buildpack `ship-it` job in `cf-release`. Pressing it can publish
buildpacks other than your own, so it is worth understanding before you press it.

1. `ship-it` writes a single **shared** trigger file
   ([task](../tasks/cf-release/write-buildpack-release-trigger-file)) to the
   `buildpack-release-triggers-shared` bucket.
2. Every `update-<bp>-release-trigger` job gets that file with `trigger: true`,
   so all of them fire, for every buildpack.
3. Each also gets `<bp>-buildpack-release-rc` with `passed: [cats]`. The `cats`
   job takes *every* buildpack's RC as an input, so any RC that made it through
   `deploy` and `cats` qualifies -- not only yours.
4. `update-<bp>-release-trigger`
   ([task](../tasks/cf-release/update-buildpack-release-trigger)) bumps
   `<bp>-buildpack-release-trigger` only if the cats-passed RC version is newer
   than the current trigger version.
5. `publish-<bp>-buildpack-release` gets that trigger with `trigger: true`, so it
   fires only if step 4 actually changed it.

The rule that follows: **an RC version ahead of the published version means that
buildpack publishes.** Equal versions leave the trigger unchanged and nothing
happens. A pending buildpack can sit for weeks because nobody pressed `ship-it`
since its RC was bumped, and then go out under someone else's press.

This is not hypothetical. When java-buildpack 5.0.6 was shipped on 2026-07-17,
php-buildpack 5.1.0 published alongside it -- its RC had been pending since early
July.

### Checking what you are about to publish

Before pressing `ship-it`, compare each buildpack's latest release candidate
against its last published version.

* **Latest RC** -- open the resource page directly:
  `.../pipelines/cf-release/resources/<bp>-buildpack-release-rc`. The newest entry
  is at the top, named `<bp>-buildpack-release-<version>-<timestamp>.tgz`.
* **Last published version** -- look it up on
  [bosh.io](https://bosh.io/releases/github.com/cloudfoundry/java-buildpack-release?all=1),
  which lists every published version of the BOSH release.

If the RC version is **ahead** of the published version, that buildpack publishes
when you press `ship-it`. If they match, nothing happens for it.

It is normal to find a buildpack other than your own in this state. If you are not
sure whether it should go out, ask the team before pressing.

> **Only look at these pages -- do not click anything on them.** Each version row
> carries a checkmark and a pin control. The checkmark disables that version and
> the pin pins it; both change pipeline behaviour and neither is what you want
> here. Read the version list and nothing more.

---

## Release checklist

- [ ] `specs-switchblade-docker-cflinuxfs4` and `-cflinuxfs5` are green
- [ ] `create-cf-infrastructure-and-execute-integration-test-for-java` is green
      (manual check -- not a gate)
- [ ] `detect-new-version-and-upload-artifacts` timestamp is correct
- [ ] `java-buildpack` `ship-it` succeeded and GitHub release `v5.0.6` exists
- [ ] `trigger-buildpack-pipeline` succeeded and the bosh-release commit was created
- [ ] `create-java-buildpack-dev-release` and `deploy` succeeded
- [ ] `cats` is green
- [ ] Checked which other buildpacks would publish (see above)
- [ ] `cf-release` `ship-it` succeeded and an RC exists for 5.0.6
- [ ] `update-java-buildpack-release-trigger` and `publish-java-buildpack-release`
      show 5.0.6
- [ ] 5.0.6 is listed on bosh.io

## Glossary

* **CATS** -- [CF Acceptance Tests](https://github.com/cloudfoundry/cf-acceptance-tests),
  run by the `cats` job in `cf-release` against a deployed CF
* **RC** -- release candidate; the `java-buildpack-release-<version>-<timestamp>.tgz`
  tarball in `bosh-release-candidates/`
* **bosh-release** -- the BOSH-packaged buildpack, in the
  [java-buildpack-release](https://github.com/cloudfoundry/java-buildpack-release)
  repository
* **cflinuxfs4 / cflinuxfs5** -- rootfs stack variants; every release ships both

## Further reading

* [Releasing a new Cloud Foundry buildpack version](https://docs.cloudfoundry.org/buildpacks/releasing_a_new_buildpack_version.html)
  -- upstream docs. The flow matches, but the job names are older
  (`buildpack-to-github`, `recreate-bosh-lite`).
* [java-buildpack](https://github.com/cloudfoundry/java-buildpack) and
  [java-buildpack-release](https://github.com/cloudfoundry/java-buildpack-release)
* [Published BOSH releases on bosh.io](https://bosh.io/releases/github.com/cloudfoundry/java-buildpack-release?all=1)
