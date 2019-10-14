Datadog
*******

This repo offers a way to emit Honeydipper internal metrics to datadog

Installation
============

Include the following section in your **init.yaml** under **repos** section

.. code-block:: yaml

   - repo: https://github.com/honeydipper/honeydipper-config-essentials
     branch: DipperCL
     path: /datadog

Drivers
=======

This repo provides following drivers

datadog-emitter
---------------

This driver enables Honeydipper to emit internal metrics to datadog so we can monitor how Honeydipper is performing.


**Configurations**

:statsdHost: The host or IP of the datadog agent to which the metrics are sent to, cannot be combined with :code:`useHostPort`


:useHostPort: boolean, if true, send the metrics to the IP specified through the environment variable :code:`DOGSTATSD_HOST_IP`, which usually is set to k8s node IP using :code:`fieldRef`.


:statsdPort: string, the port number on the datadog agent host to which the metrics are sent to

For example

.. code-block:: yaml

   ---
   drivers:
     datadog-emitter:
       useHostPort: true
       statsdPort: "8125"
   

RPC: counter_increment
^^^^^^^^^^^^^^^^^^^^^^^^^

Increment a counter metric

**Parameters**

:name: The metric name

:tags: A list of strings to be attached as tags

For example, calling from a driver


.. code:: go

   driver.RPC.Caller.CallNoWait(driver.Out, "emitter", "counter_increment", map[string]interface{}{
     "name": "myapp.metric.counter1",
     "tags": []string{
       "server1",
       "team1",
     },
   })


RPC: gauge_set
^^^^^^^^^^^^^^^^^

Set a gauge value

**Parameters**

:name: The metric name

:tags: A list of strings to be attached as tags

:value: String, the value of the metric

For example, calling from a driver


.. code:: go

   driver.RPC.Caller.CallNoWait(driver.Out, "emitter", "gauge_set", map[string]interface{}{
     "name": "myapp.metric.gauge1",
     "tags": []string{
       "server1",
       "team1",
     },
     "value": "1000",
   })


