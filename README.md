# AICTE Scraper

Scrapes information on colleges from AICTE's website, and stores it in YAML form.

## Example Output

    ---
    Andaman and Nicobar Islands:
      colleges:
        1-2811997238:
          name: Dr. B.R. Ambedkar Institute Of Technology
          address: Polytechnic Road Pahar Gaon Po Junglighat
          district: Port Blair
          institution_type: Government
          universities:
          - Maharashtra State Board of Technical Education, Mumbai
          - Pondicherry University,
        1-2877581491:
          name: Multidisciplinary Professional College
          address: Pheonix Bay Sts Building
          district: Port Blair
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

## TODO

* Cache index data in memory before dumping to file.
* <strike>Speed up the process by calling URL-s in parallel.</strike>
