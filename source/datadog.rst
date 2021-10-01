Datadog
*******

This repo offers a way to emit Honeydipper internal metrics to datadog

Installation
============

Include the following section in your **init.yaml** under **repos** section

.. code-block:: yaml

   - repo: https://github.com/honeydipper/honeydipper-config-essentials
     branch: main
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


Systems
=======

datadog
-------

This system enables Honeydipper to integrate with `datadog`, so Honeydipper can
emit metrics using workflows or functions.

The system doesn't take authentication configuration, but uses configuration from the
:code:`datadog-emitter` driver. See the driver for details.


**Configurations**

:heartbeat_metric: Uses this metric to track all heartbeats with different tags.

Function: heartbeat
^^^^^^^^^^^^^^^^^^^

This function will send a heartbeat request to datadog.


**Input Contexts**

:heartbeat: The prefix of the heartbeat metric name used for tagging.

:heartbeat_expires: Tag the metric with expiring duration, used for creating monitors.

:heartbeat_owner: The owner of the heartbeat, used as the suffix of the metric name.

Function: increment
^^^^^^^^^^^^^^^^^^^

This function will increment a counter metric.


**Input Contexts**

:metric: The name of the metric.

:tags: Optional, a list of strings as tags for the metric.

Function: set
^^^^^^^^^^^^^

This function will set a gauge metric.


**Input Contexts**

:metric: The name of the metric.

:tags: Optional, a list of strings as tags for the metric.

:value: The value of the metric.

