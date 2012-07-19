Network.Metrics
===============

Table of Contents
-----------------

* [Usage](#usage)
* [API](#api)
* [GMetric](#gmetric)
* [Contribute](#contribute)
* [Licence](#licence)


<a name="usage" />

Usage
-----

All modules including `Network.Metrics` expose the same interfaces to sinks, and re-export
the required types for constructing metrics.

Supported Sinks:

* `Network.Metrics.Ganglia`
* `Network.Metrics.Graphite`
* `Network.Metrics.Statsd`

> A `stdout` sink is available in the top-level `Network.Metrics` module.


**To use the unified sink type:**

````haskell
{-# LANGUAGE OverloadedStrings #-}

import Network.Metrics

main = do
    sink <- open Ganglia "localhost" "1234"
    push sink sink
    close sink
  where
    metric = Metric Counter "name.space" "bucket" "1234" -- Creates ganglia key: "name.space.bucket"
````

**To use a specific sink directly:**

````haskell
{-# LANGUAGE OverloadedStrings #-}

import Network.Metrics.Graphite

main = do
    sink <- open "localhost" "1234"
    push sink sink
    close sink
  where
    metric = Metric Counter "name.space" "bucket" "1234" -- Creates graphite key: "name.space.bucket"
````


<a name="api" />

API
---

Preliminary API documentation is available [on Hackage](http://hackage.haskell.org/package/network-metrics).

> The API is currently in flux, and conversion between the universal `Metric` `Counter` `Gauge` `Timing` type to the respective sink types is not completed.


<a name="gmetric" />

GMetric
-------

A port of Ganglia's `gmetric` is built by default under the name `gmetric-haskell`.


<a name="contribute" />

Contribute
----------

For any problems, comments or feedback please create an issue [here on GitHub](github.com/brendanhay/network-metrics/issues).


<a name="licence" />

Licence
-------

Stetson is released under the [Mozilla Public License Version 2.0](http://www.mozilla.org/MPL/)
