[HowTo] Droits multiples et ACL sous Debian
===========================================

.. article-info::
    :date: Aug 06, 2010
    :read-time: 10 min read

Les droits de fichier Unix classiques ne nous permettent pas d'autoriser plusieurs 
groupes avec un accès en lecture/écriture et d'autres groupes (ou utilisateurs) avec un 
accès en lecture seule.
Heureusement il existe les ACL (acces control list) c'est une liste composée de 
plusieurs règles en fonction de l'utilisateur, elle permet donc de palier à ce défaut. 
Installées par défauts sur certains systèmes, ces “Listes de contrôles d'accès” peuvent 
s'avérer très utiles lors d'un partage Samba par exemple.

Utilité et exemple
~~~~~~~~~~~~~~~~~~

Admettons un partage de fichiers samba dans une PME avec un dossier… Royalbacon, pour 
changer.
Le patron doit avoir un controle total sur RoyalBacon
Les commerciaux les droits de lecture et exécution
Et  les client uniquement un droit de lecture seule

Voilà un cas pratique ou nous allons devoir gérer les droits du dossier avec une liste 
de contrôle d'accès ou ACL.

Installation
~~~~~~~~~~~~

.. code-block:: bash

    aptitude install acl

Activer le support des ACL au demarrage
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Afin qu'une partition Unix supporte les ACL il faut la monter avec l'option “ACL”
Pour cela nous allons éditer le fichier fstab contenant les paramètres de montage des 
partitions au démarrage.

Commencez par repérer la partition à modifier, par exemple ” sdc2 ” chez moi.
Pour vous y retrouver:

- La première lettre correspond au type de disque dur “H” pour l'IDE et “S” pour les 
  disques SCSI ou SATA.
- La troisième au numéro du disque “a” pour le premier, “b” pour le deuxieme etc…
- Et le numéro final correspond à celui de la partition sur le disque.

Ensuite éditez le fichier “fstab”

.. code-block:: bash
    
    vi /etc/fstab

Et modifiez la ligne de votre partition pour y ajouter l'option “acl”:
Chez moi:

.. code-block:: bash
    
    /dev/sdc2       /storage/shared        ext3    defaults,acl        0       2

ou pour que ce soit effectif dès maintenant, remontez la partition avec le paramètre 
“acl”:

.. code-block:: bash
    
    mount -o remount,acl /dev/sdc2

Configurer les ACL pour un fichier ou un dossier
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Les commandes utilisées sont getfacl et setfacl

.. code-block:: bash    

    getfacl permet de lister les droits,

un peu comme un “ls -l” mais spécifique à un élément et plus poussé. Il s'utilise avec 
la syntaxe suivante: ``getfacl nomdefichier .``
Par exemple pour le fichier ``royalbacon.mcdo``:

getfacl royalbacon.mcdo
setfacl sert, lui, à configurer une ACL sur un fichier (ou un dossier).
la syntaxe est la suivante: setfacl -[m/b] type:nom:droits nomdufichier
On peu la décomposer en 5 paramètres

- -m sert à ajouter une règle et -b à supprimer les règles
- type: o, g ou o pour user, group ou other
- droits r, w et/ou x pour read, write et execute
- nom: nom de l'utilisateur ou du groupe

Par exemple, pour ajouter les droits d'écriture à l'utilisateur epheo sur le fichier 
``royalbacon.mcdo``:

.. code-block:: bash
    
    setfacl -m u:epheo:w royalbacon.mcdo

Pour supprimer l' ACL du fichier royalbacon.mcdo:

.. code-block:: bash
    
    setfacl -b royalbacon.mcdo

Remarques, autres paramètres et exemples concrets
Le paramètre -R (pour la récursivité) fonctionne:

.. code-block:: bash
    
    setfacl -b -R royalbacon.mcdo

Evidemment avec le parametre o (other) on ne specifie pas de nom d'utlisateur :)
Par exemple pour donner les droits de lecture aux autres utilisateurs:

.. code-block:: bash
    
    setfacl -m o::r royalbacon.mcdo

Une dernière remarque, lors d'un partage samba, Windows peut modifier les ACL 
graphiquement, avec l'explorer. (oui c'est étonnant je sais…)
