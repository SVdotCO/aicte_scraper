# AICTE Scraper

Scrapes information on colleges from AICTE's website, and stores it in YAML form.

## Output

In the interest of saving everyone time (and to spare AICTE's webserver), cached files are available in the `output` directory.

This script will check whether existing data is up-to-date (one URL call per state) before attempting a rebuild.

To force a rebuild, empty the cache.

### Format

    ---
    Andaman and Nicobar Islands:
      colleges:
        1-2811997238: # <- AICTE's ID for a college.
          name: DR. B.R. AMBEDKAR INSTITUTE OF TECHNOLOGY
          address: POLYTECHNIC ROAD PAHAR GAON PO JUNGLIGHAT
          district: PORT BLAIR
          institution_type: Government
          universities:
          - Maharashtra State Board of Technical Education, Mumbai
          - Pondicherry University
        1-2877581491:
          name: MULTIDISCIPLINARY PROFESSIONAL COLLEGE
          address: PHEONIX BAY STS BUILDING
          district: PORT BLAIR
          institution_type: Government
          universities:
          - Panjab University, Chandigarh
        ...

## Requirements

* Ruby > 2.0.0

## Instructions

    bundle install
    bundle exec ruby scrape.rb --help

    Usage: scrape.rb [options]
        -s, --state STATE                Choose state
        -p, --processes COUNT            Number of processes to run simultaneously

Output will be stored to `outputs/[STATE].yml`

To load info for a single state:

    bundle exec ruby scrape.rb -s "Andaman and Nicobar Islands"

You can speed up scraping by running multiple processes, at the risk hitting the AICTE server's rate limiter (handled). I'm not sure what the rate limit is, so there's no way to automatically run at maximum speed at the moment.

    bundle exec ruby scrape.rb -p 4

For a list of valid states, check `AicteScraper::Constants`.
