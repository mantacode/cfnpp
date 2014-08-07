# cfnpp

Cloudformation Preprocessor

## Installation

While in the cfnpp repo directory

```
$ sudo ./install.sh
```

That will build the gem and install it locally. Requires bundler.

If you want to install on Windows... probably don't do that, but just read the (very short) shell script.

Will move this over to Rake soon.

## Usage

If you've used launch2, the cfnpp tool works more or less the same way.

If you're in the cloudformationt-tools directory, do

```
$ cfnpp -b ./stacks $whatever_else
```

and you can use it just like launch2. "-b" sets the base path for stacks.

Bundler makes life good but a little weird, so if you have problems running it at all,
or an error about ```cfnpp/transform```, that's why.
