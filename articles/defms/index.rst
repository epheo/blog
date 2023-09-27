DEFMS: For a distributed, encrypted and free email delivery network
====================================================================

.. admonition:: Date and Author
   :class: note
   
   Thibaut Lapierre | February 24, 2018
   
Let’s have a closer look at the current implementation of our global email delivery 
system.

It scaled out from the very early stage of our network while all mail addresses was 
summed up in a paper book to our current multi-billion addresses directory quite 
impressively, the workload and delivery effort is mostly shared across the few biggest 
current IT and telecom companies and the required bandwidth and data effort is 
duplicated between all sender, receivers and intermediates of the transmission. 
Content encryption or signature is still a marginal practice and while normally not 
accessible by a random tiers, the relevant intermediates and providers do not hesitate 
to monitor and analyze our day to day exchanges. Content is easily reversible, which 
so prevent (or at least should prevent) them to have any juridical value.

As of today, we used the available technologies and paradigms to scale from an 
inter-lab experiment to a multi-billion connection delivery network, but as new 
paradigms and technologies arrived, we now have all the tools to create a new email 
delivery network, compatible with the current protocols, that better suits our 
everyday needs.

Regarding how fast the importance of this media grew up those past two decades, one 
would now want to be able to rely on multiple sources for the storage and transport of 
his messages without having to necessarily trust those third-parties, one would also 
like to guaranty the integrity, the consistency and the immutability in time of his 
exchanges with someone. An entirely distributed, partly encrypted and free mail 
exchange system would allow us to communicate directly with the concerned receivers 
without restrictions of size, number, consistency or availability of the exchanged 
messages. Applications are numerous but more importantly this will help us reducing the 
total amount of storage and bandwith required by mail exchanges.

As encryption, peer to peer and data immutability are already widespread principles one 
remaining pain-point is in the compatibility with our existing systems and protocols. 
Such a compatibility with actual mail protocols will be achieved by non-ditributed 
gateway servers, this long-term temporary solution will encrypt and forward all email 
from standard MX systems to and from DEFMS.

https://def.ms