# Ruby Gaming

A Rails 8.1 gaming site: user accounts, IGDB game search, and per-user game
collections. Requires Ruby (see `.ruby-version`) and a local Postgres
(`brew services start postgresql@17`).

## Developer commands

```
bin/setup                  # install gems, prepare the database
bin/rails server           # run the app at http://localhost:3000
bin/rails console          # Ruby console with the app loaded
bin/rails db:migrate       # apply pending migrations
bin/rails routes           # list all routes

bin/rails test             # model, controller, integration, service tests (no browser)
bin/rails test:system      # browser tests (Capybara + headless Chrome)
bin/rails test:all         # everything above
bin/rails test path/to/file_test.rb:LINE   # one file, or one test by line

RUN_IGDB_INTEGRATION=1 bin/rails test test/services/igdb_client_live_test.rb
                           # opt-in smoke test against the live IGDB API
                           # (needs real credentials; skipped by default)

bin/rubocop                # style check
bin/brakeman               # security scan
bin/ci                     # CI run: setup, rubocop, security audits, tests, seeds
                           # (system tests are not included; see config/ci.rb)
```

Rails "integration tests" (`test/integration/`) are plain HTTP-level tests
with no browser, so they run as part of `bin/rails test`. Only system tests
need `test:system`.
