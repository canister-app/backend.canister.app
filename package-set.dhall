let upstream = https://github.com/dfinity/vessel-package-set/releases/download/mo-0.9.1-20230516/package-set.dhall sha256:b46f30e811fe5085741be01e126629c2a55d4c3d6ebf49408fb3b4a98e37589b

let Package =
    { name : Text, version : Text, repo : Text, dependencies : List Text }

let
  -- This is where you can add your own packages to the package-set
  additions =
    [
      { name = "sha256"
        , repo = "https://github.com/enzoh/motoko-sha.git"
        , version = "9e2468f51ef060ae04fde8d573183191bda30189"
        , dependencies = [ "base" ]
      },
       { name = "accountid"
      , repo = "https://github.com/stephenandrews/motoko-accountid"
      , version = "06726b1625fea8870bc8c248d661b11a4ebfe7ae"
      , dependencies = [ "base" ]
      }
] : List Package

let
  {- This is where you can override existing packages in the package-set

     For example, if you wanted to use version `v2.0.0` of the foo library:
     let overrides = [
         { name = "foo"
         , version = "v2.0.0"
         , repo = "https://github.com/bar/foo"
         , dependencies = [] : List Text
         }
     ]
  -}
  overrides =
    [] : List Package

in  upstream # additions # overrides
