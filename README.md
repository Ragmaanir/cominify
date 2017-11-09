# cominify 0.1.0

Minify comics in CBR, CBT, CBA, CB7, PDF format by converting images to WEBP.
Only a few comic viewers can display WEBP files. I use [pynocchio](https://github.com/pynocchio/pynocchio). Cominify uses `/dev/shm` for temporary files.

## Installation

`git clone git@github.com:Ragmaanir/cominify.git`

## Usage

```bash
crystal run src/cominify -- -i original_comics -o minified_comics -q 75
```

## Contributing

1. Fork it ( https://github.com/ragmaanir/cominify/fork )
2. Create your feature branch (git checkout -b my-new-feature)
3. Commit your changes (git commit -am 'Add some feature')
4. Push to the branch (git push origin my-new-feature)
5. Create a new Pull Request

## Contributors

- [ragmaanir](https://github.com/ragmaanir) - creator, maintainer
