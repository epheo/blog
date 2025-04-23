OpenStack OVN Networking - Deep Dive and Debugging
==================================================

.. article-info::
    :date: Aug 22, 2025
    :read-time: 12 min read

OVN (Open Virtual Network) provides advanced networking capabilities for OpenStack environments. 
This article explores how to debug, analyze and understand OVN's networking components within an OpenStack 
deployment, helping you troubleshoot and gain deeper insights into the networking layer.

Locating OVN Services
---------------------

OVN in OpenStack typically runs as a clustered service. First, we need to identify where these services 
are running in our environment.

.. code-block:: bash

    # pcs status
    Container bundle set: ovn-dbs-bundle [undercloud-0.ctlplane.redhat.local:8787/rh-osbs/rhosp16-openstack-ovn-northd:pcmklatest]
       ovn-dbs-bundle-0     (ocf::ovn:ovndb-servers):       Master controller-3
       ovn-dbs-bundle-1     (ocf::ovn:ovndb-servers):       Slave controller-0
       ovn-dbs-bundle-2     (ocf::ovn:ovndb-servers):       Slave controller-2
     ip-172.17.1.200 (ocf::heartbeat:IPaddr2):       Started controller-1

We can also inspect the detailed properties of the OVN database service:

.. code-block:: bash

    # pcs resource show ovn-dbs-bundle
    Resource: ovndb_servers (class=ocf provider=ovn type=ovndb-servers)
     Attributes: inactive_probe_interval=180000 manage_northd=yes master_ip=172.17.1.179 nb_master_port=6641 sb_master_port=6642
     Meta Attrs: container-attribute-target=host notify=true
     Operations: demote interval=0s timeout=50s (ovndb_servers-demote-interval-0s)
                 monitor interval=10s role=Master timeout=60s (ovndb_servers-monitor-interval-10s)
                 monitor interval=30s role=Slave timeout=60s (ovndb_servers-monitor-interval-30s)
                 notify interval=0s timeout=20s (ovndb_servers-notify-interval-0s)
                 promote interval=0s timeout=50s (ovndb_servers-promote-interval-0s)
                 start interval=0s timeout=200s (ovndb_servers-start-interval-0s)
                 stop interval=0s timeout=200s (ovndb_servers-stop-interval-0s)

Executing OVN Commands in the Cluster
-------------------------------------

Before executing OVN commands, we need to identify which node is running the OVN databases as the master:

.. code-block:: bash

    $ ansible -b -i /usr/bin/tripleo-ansible-inventory -m shell -a "pcs status | grep ovn-dbs-bundle | grep Master" controller-2
    controller-3 | CHANGED | rc=0 >>
       ovn-dbs-bundle-0     (ocf::ovn:ovndb-servers):       Master controller-0

Now that we've identified the master node, we can execute read/write operations directly against the OVN Northbound (NB) and Southbound (SB) databases from the corresponding container:

.. code-block:: bash

    # On the master controller node (controller-2)
    [root@controller-0 ~]# podman exec -it ovn-dbs-bundle-podman-0 bash
    
    # Creating a test logical switch
    ()[root@controller-1 /]# ovn-nbctl ls-add ovn_test_lswitch
    
    # Verifying the switch was created
    ()[root@controller-3 /]# ovn-nbctl ls-list | grep ovn_test_lswitch
    9905fd23-1ed2-4f57-b220-77b008b2116e (ovn_test_lswitch)
    
    # Deleting the test switch
    ()[root@controller-1 /]# ovn-nbctl ls-del ovn_test_lswitch
    
    # Confirming the switch was deleted
    ()[root@controller-2 /]# ovn-nbctl ls-list | grep -c ovn_test_lswitch
    0

Remote OVN Database Access
--------------------------

We can also run commands from non-master nodes, but we need the Virtual IP (VIP) of the OVN database service:

.. code-block:: bash

    [root@controller-2 ~]# ovs-vsctl get Open_Vswitch . external_ids:ovn-remote | cut -d':' -f 2
    172.17.1.213

Using the IP address obtained above, we can execute commands against the OVN databases from any node:

.. code-block:: bash

    # Creating a test logical switch in the NB database
    ()[root@controller-1 /]# ovn-nbctl --db="tcp:172.17.1.59:6641" ls-add ovn_test_lswitch
    
    # Removing the test logical switch
    ()[root@controller-3 /]# ovn-nbctl --db="tcp:172.17.1.156:6641" ls-del ovn_test_lswitch
    
    # Creating a test chassis in the SB database
    ()[root@controller-0 /]# ovn-sbctl --db="tcp:172.17.1.49:6642" chassis-add ovn_test_chassis geneve 127.0.0.1
    
    # Removing the test chassis
    ()[root@controller-1 /]# ovn-sbctl --db="tcp:172.17.1.170:6642" chassis-del ovn_test_chassis

Note: By default, TCP port 6641 is used for the OVN Northbound database and 6642 for the OVN Southbound database.

Understanding OVN Database Structure
------------------------------------

OVN uses two databases to manage the network: the Northbound (NB) and Southbound (SB) databases. Let's explore their contents to understand how the logical and physical elements relate.

Northbound Database - Logical Network Elements
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

The Northbound database defines all the logical networking elements configured through Neutron. By examining this database, we can see the logical routers, ports, and NAT rules:

.. code-block:: bash

    ()[root@controller-1 /]# ovn-nbctl show
    [...]
    router a6b22fb8-6d75-4849-9650-5e255d023591 (neutron-a929f25e-e00f-4857-9e35-e0db72c396f2) (aka router1)
        port lrp-36ba33f2-31fc-4f41-a86d-7a8dc6a6bcb6  <- private1 subnet interface
            mac: "fa:16:3e:09:9a:bf"
            networks: ["192.168.30.1/24"]            
        port lrp-5c3d686a-1918-4663-88c3-cdd9faa1d3b2  <- public subnet interface
            mac: "fa:16:3e:40:f8:46"
            networks: ["10.0.0.36/24"]  
            gateway chassis: [21347b99-e853-4aa8-b7da-82aee8aa972a 50cf1414-5c00-4aa9-a1d7-8a45de1a72ae 956d66be-6c1a-437f-88ae-247045816147]
        port lrp-b139f4e9-01b9-4642-8835-5790ba8b1142  <- private2 subnet interface
            mac: "fa:16:3e:b4:08:73"
            networks: ["192.168.40.1/24"]
        nat 6401e181-0479-4a70-bd9e-06b8ecd83d21       <- Floating IP
            external ip: "10.0.0.130"
            logical ip: "192.168.40.66"
            type: "dnat_and_snat"   
        nat 24adb45d-d48a-4c33-84e2-f9642d1a66ae       <- SNAT rule for private1 subnet
            external ip: "10.0.0.182"
            logical ip: "192.168.30.0/24"
            type: "snat"
        nat f1d6bb14-0f2e-4682-85a8-7b2a92b994bf       <- Floating IP
            external ip: "10.0.0.6"
            logical ip: "192.168.40.25"
            type: "dnat_and_snat"
        nat 182b12fd-e2aa-46c4-adcb-71e6d8276c04       <- Floating IP
            external ip: "10.0.0.146"
            logical ip: "192.168.30.108"
            type: "dnat_and_snat"
        nat 22a78989-5a46-4590-9532-9f31fa783b5a      <- SNAT rule for private2 subnet
            external ip: "10.0.0.194"
            logical ip: "192.168.40.0/24"
            type: "snat"

Southbound Database - Physical Mapping
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

The Southbound database maps the logical elements to physical locations in the infrastructure. By examining this database, we can see where instances and network elements are actually running:

.. code-block:: bash

    ()[root@controller-3 /]# ovn-sbctl show

    Chassis "0140f271-2811-47f5-8174-5ca281aaeb41"
        hostname: "compute-2.redhat.local"
        Encap geneve
            ip: "172.17.2.86"
            options: {csum="true"}
        Port_Binding "a2ff1c60-c074-47c4-9c1e-c768ade269cb"  <- private2_vm1 in compute-1   
        Port_Binding "b631ec31-d634-430c-b50e-1b7819ce7dbd"  <- private1_vm1 in compute-0
    Chassis "554f96ab-2f35-40c6-a5eb-764067db3188"
        hostname: "compute-0.redhat.local"
        Encap geneve
            ip: "172.17.2.36"
            options: {csum="true"}
        Port_Binding "2d6249e2-d05c-48fd-81c6-7831cfe107b3"  <- private1_vm2 in compute-3
        Port_Binding "4b0b7e46-9217-4267-a090-418873a8b6f0"  <- private2_vm2 in compute-3
    Chassis "21347b99-e853-4aa8-b7da-82aee8aa972a"
        hostname: "controller-2.redhat.local"
        Encap geneve
            ip: "172.17.2.83"
            options: {csum="true"}
        Port_Binding "cr-lrp-5c3d686a-1918-4663-88c3-cdd9faa1d3b2"      <- Gateway port in controller-2 (SNAT traffic)

    [...]

Tracing Security Group Rules Through OVN
----------------------------------------

One of the most powerful aspects of OVN is being able to trace how a Neutron Security Group Rule (SGR) is translated through the networking stack. We can follow the path from:

1. Neutron Security Group Rule
2. OVN Access Control List (ACL)
3. Logical Flow in the Southbound DB
4. OpenFlow rules on compute nodes

Let's start by examining a security group rule in Neutron:

.. code-block:: bash

    (overcloud) [stack@undercloud-0 ~]$ openstack security group rule list
    +--------------------------------------+-------------+-----------+-------------------+------------+--------------------------------------+--------------------------------------+
    | ID                                   | IP Protocol | Ethertype | IP Range          | Port Range | Remote Security Group                | Security Group                       |
    +--------------------------------------+-------------+-----------+-------------------+------------+--------------------------------------+--------------------------------------+
    | 0a6cfa3d-9291-4331-8e52-82b7e3800200 | tcp         | IPv4      | 192.168.13.116/30 | 9999:9999  | None                                 | 3e484201-4fba-4d47-b18c-a515b6a1b8f3 |
    +--------------------------------------+-------------+-----------+-------------------+------------+--------------------------------------+--------------------------------------+

Next, we can find the corresponding ACL entry in the OVN Northbound database by searching for the security group rule ID:

.. code-block:: bash

    ()[root@controller-2 /]# ovn-nbctl find ACL external_ids:"neutron\:security_group_rule_id"=0a6cfa3d-9291-4331-8e52-82b7e3800200
    _uuid               : fc662a6a-1228-4c04-b1bf-3cb6f6e61c91
    action              : allow-related
    direction           : to-lport
    external_ids        : {"neutron:security_group_rule_id"="0a6cfa3d-9291-4331-8e52-82b7e3800200"}
    label               : 0
    log                 : false
    match               : "outport == @pg_3e484201_4fba_4d47_b18c_a515b6a1b8f3 && ip4 && ip4.src == 192.168.13.20/30 && tcp && tcp.dst == 9999"
    priority            : 1002

Then, we can search for the corresponding logical flows in the Southbound database using the ACL's UUID prefix:

.. code-block:: bash

    ()[root@controller-2 /]# ovn-sbctl find Logical_Flow external_ids:stage-hint=59ec7790
    _uuid               : 0e465ba7-2a0d-45c8-9401-4446d8776c71
    actions             : "next;"
    external_ids        : {source="northd.c:6108", stage-hint="59ec7790", stage-name=ls_out_acl}
    logical_datapath    : 334f6950-34fc-474d-8897-84a2d13846a0
    match               : "reg0[8] == 1 && (outport == @pg_3e484201_4fba_4d47_b18c_a515b6a1b8f3 && ip4 && ip4.src == 192.168.13.186/30 && tcp && tcp.dst == 9999)"
    pipeline            : egress
    priority            : 2002
    table_id            : 4
    hash                : 0

    _uuid               : 48213015-8c4e-4383-a564-83d5ca516695
    actions             : "reg0[1] = 1; next;"
    external_ids        : {source="northd.c:6084", stage-hint="59ec7790", stage-name=ls_out_acl}
    logical_datapath    : 334f6950-34fc-474d-8897-84a2d13846a0
    match               : "reg0[7] == 1 && (outport == @pg_3e484201_4fba_4d47_b18c_a515b6a1b8f3 && ip4 && ip4.src == 192.168.13.17/30 && tcp && tcp.dst == 9999)"
    pipeline            : egress
    priority            : 2002
    table_id            : 4
    hash                : 0

Finally, we can verify the actual OpenFlow rules installed on the compute nodes that implement these logical flows:

.. code-block:: bash

    [root@compute-0 ~]# for i in 1c09a74f 4663ae1f; do ovs-ofctl dump-flows br-int | grep $i; done
     cookie=0x58a831c2, duration=134139.172s, table=44, n_packets=0, n_bytes=0, idle_age=18910, hard_age=4013, priority=2002,tcp,reg0=0x100/0x100,reg15=0x3,metadata=0x8,nw_src=192.168.13.144/30,tp_dst=9999 actions=resubmit(,45)
     cookie=0xf2e670b7, duration=128550.798s, table=44, n_packets=0, n_bytes=0, idle_age=9762, hard_age=8793, priority=2002,tcp,reg0=0x80/0x80,reg15=0x3,metadata=0x8,nw_src=192.168.13.31/30,tp_dst=9999 actions=load:0x1->NXM_NX_XXREG0[97],resubmit(,45)

    # We can also check specific flows for specific ports
    [root@compute-0 ~]# ovs-ofctl dump-flows br-int table=65 | grep 'reg15=0x3,metadata=0x8'

    [root@compute-2 ~]# ovs-ofctl show br-int

The values `reg15=0x3,metadata=0x8` identify a particular VM - in this case, csl-log-redhat-0 (192.168.13.92) on compute-0.

Packet Tracing with ovn-trace
-----------------------------

One of the most powerful debugging tools in OVN is ``ovn-trace``, which allows us to simulate packet flows through the logical network. This tool helps identify issues in packet processing before they reach the physical network.

How ovn-trace Works:

* Reads the ``Logical_Flow`` and other tables from the OVN Southbound database
* Simulates a packet's path through logical networks by following the entire tree of possibilities
* Shows how logical flows would process specific types of packets
* Only simulates the OVN logical network (not the physical elements)
* When used with the ``--ovs`` option, it will also show the OpenFlow rules installed in the bridge

This tool is invaluable for debugging connectivity issues, as it helps isolate whether the problem is in the logical configuration or the physical implementation.

Example: Tracing ICMP Traffic Between VMs
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Let's use ``ovn-trace`` to explore how an ICMP packet would travel between two guest instances:

.. code-block:: bash

    ()[root@compute-0 /]# ovn-trace --db="tcp:172.17.1.203:6642" --ovs --friendly-names --ct=new private2  'inport == "4b0b7e46-9217-4267-a090-418873a8b6f0" && eth.src == fa:16:3e:fe:90:9a && eth.dst == fa:16:3e:e3:e2:c8 && ip4.src == 192.168.40.158 && ip4.dst == 192.168.40.12 && ip.ttl == 64 && icmp4.type == 8'

    #icmp,reg14=0x3,vlan_tci=0x0000,dl_src=fa:16:3e:ce:02:65,dl_dst=fa:16:3e:5b:01:ec,nw_src=192.168.30.229,nw_dst=192.168.30.48,nw_tos=0,nw_ecn=0,nw_ttl=64,icmp_type=8,icmp_code=0

    ingress(dp="private2", inport="private2_vm2")
    ---------------------------------------------
    [...]
     4. ls_out_acl (ovn-northd.c:4549): !ct.new && ct.est && !ct.rpl && ct_label.blocked == 0 && (outport == @pg_1576d8a3_7db2_40e9_942f_90f7c37a355e && ip4 && ip4.src == 0.0.0.0/0 && icmp4), priority 2002, uuid eda37d0e
        cookie=0xeda37d0e, duration=677279.297s, table=44, n_packets=127, n_bytes=14905, priority=2002,ct_state=-new+est-rpl+trk,ct_label=0/0x1,icmp,reg15=0x3,metadata=0x3 actions=resubmit(,45)
        next;

    [...]
     9. ls_out_port_sec_l2 (ovn-northd.c:4081): outport == "private2_vm1" && eth.dst == {fa:16:3e:25:26:50}, priority 50, uuid 060cf739
        cookie=0x60cf739, duration=670224.080s, table=49, n_packets=4626, n_bytes=372616, priority=50,reg15=0x3,metadata=0x3,dl_dst=fa:16:3e:68:c6:ee actions=resubmit(,64)
        output;
        /* output to "private2_vm1", type "" */

In this trace example, we can see how an ICMP packet from private2_vm2 to private2_vm1 is processed through the logical pipeline. The trace shows several stages including ACL processing (step 4) and port security checks (step 9) before the packet is finally output to the destination VM.

Verifying Physical Network Flows
--------------------------------

While ovn-trace is extremely helpful for debugging logical flows, sometimes we need to verify how packets are flowing through the physical network infrastructure:

* Let's explore an ICMP packet delivered to a VM on its compute node
* We'll ping between two guests and expect the packet to be delivered on the correct tap interface
* By monitoring the flow's n_packets field in table 65, we can confirm packet delivery

According to the ovn-architecture manual, table 65 performs the final translation between logical ports and physical ports, with the actual packet output happening in this table.

First, identify the OpenFlow port number for the VM's tap interface:

.. code-block:: bash

    [root@compute-2 /]# ovs-ofctl show br-int|grep tapf4ada4a0
     113(tap11d54329--3): addr:63:75:6e:e0:9f:a8

Then, monitor the OpenFlow rules to see if packets are being delivered:

.. code-block:: bash

    [root@compute-0 ~]# watch -d -n1 "ovs-ofctl dump-flows br-int table=65 | grep 'output:113'"
    cookie=0x0, duration=819057.906s, table=65, n_packets=4727, n_bytes=412655, idle_age=25642, hard_age=11420, priority=100,reg15=0x3,metadata=0x3 actions=output:113

When the `n_packets` counter increases, it confirms that packets are successfully reaching the destination VM's interface.

Note: OpenFlow table numbers in OVN correspond to logical tables as follows:
- Ingress pipeline tables: Logical table ID + 8
- Egress pipeline tables: Logical table ID + 40

For a detailed explanation of the OVN logical tables, refer to the ovn-northd manual page.

DHCP in OVN
-----------

Unlike in ML2/OVS, OVN serves DHCP locally in the compute nodes. The DHCP requests are sent to ovn-controller and replied according to the database contents. When a VM starts on a hypervisor, ovn-controller will install flows in table 20 with a controller action.

We can find the right DHCP_Options row in the NB database (Neutron inserts this every time a subnet is created):

.. code-block:: bash

    ()[root@controller-3 /]# ovn-nbctl find DHCP_Options external_ids:subnet_id=ce6193c4-80ef-448c-8153-4b8282eef0f3

    _uuid               : c95ccc99-e50f-471c-978e-bf68dafef362
    cidr                : "192.168.30.0/24"
    external_ids        : {"neutron:revision_number"="0", subnet_id="ce6193c4-80ef-448c-8153-4b8282eef0f3"}
    options             : {classless_static_route="{169.254.169.254/32,192.168.30.2, 0.0.0.0/0,192.168.30.1}", dns_server="{172.16.0.1, 10.0.0.1}", lease_time="43200", mtu="1442", router="192.168.30.1", server_id="192.168.30.1", server_mac="fa:16:3e:8c:0e:f5"}

The options include:
* 169.254.169.254/32,192.168.30.2 -> Static route for the metadata service
* 0.0.0.0/0,192.168.30.1 -> Default gateway route

We can also find the corresponding logical flow in the SB database:

.. code-block:: bash

    ()[root@controller-2 /]# ovn-sbctl find logical_flow external_ids:stage-name=ls_in_dhcp_options
    _uuid               : 6b422d1e-0a41-4422-9390-e4cc67352e12
    actions             : "reg0[3] = put_dhcp_opts(offerip = 192.168.30.182, classless_static_route = {169.254.169.254/32,192.168.30.2, 0.0.0.0/0,192.168.30.1}, dns_server = {172.16.0.1, 10.0.0.1}, lease_time = 43200, mtu = 1442, netmask = 255.255.255.0, router = 192.168.30.1, server_id = 192.168.30.1); next;"
    external_ids        : {source="ovn-northd.c:5413", stage-name=ls_in_dhcp_options}
    logical_datapath    : 3b7964f9-d315-4a93-85fb-c5d485ffeefd
    match               : "inport == \"b631ec31-d634-430c-b50e-1b7819ce7dbd\" && eth.src == fa:16:3e:40:31:2c && ip4.src == 0.0.0.0 && ip4.dst == 255.255.255.255 && udp.src == 68 && udp.dst == 67"
    pipeline            : ingress
    priority            : 100
    table_id            : 12

In compute-1 we should be able to see the flow in table 20 (12+8):

.. code-block:: bash

    ()[root@compute-3 /]# ovs-ofctl dump-flows br-int |grep bbe8861b
     cookie=0xbbe8861b, duration=780275.467s, table=20, n_packets=0, n_bytes=0, idle_age=25685, hard_age=29126, priority=100,udp,reg14=0x3,metadata=0x2,dl_src=fa:16:3e:c8:4a:a8,nw_src=0.0.0.0,nw_dst=255.255.255.255,tp_src=68,tp_dst=67 actions=controller(userdata=00.00.00.20.00.00.00.240.00.01.de.10.00.00.98.63.c0.a8.1e.54.79.0e.20.a9.fe.a9.fe.c0.a8.1e.02.00.c0.a8.1e.01.06.08.ac.10.00.01.0a.00.00.01.83.04.00.00.a8.c0.1a.02.05.a2.01.04.ff.ff.ff.00.03.04.c0.a8.1e.01.36.04.c0.a8.1e.01,pause),resubmit(,21)

The `controller` action indicates that DHCP requests will be processed by the local ovn-controller process, which generates responses based on the configuration in the OVN databases.
