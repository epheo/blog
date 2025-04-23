[HowTo] Installer DropBox sur un serveur Linux en CLI
=====================================================

.. article-info::
    :date: Sept 01, 2011
    :read-time: 15 min read

Fidèle utilisateur de DropBox depuis plusieurs années je me suis demandé comment 
l'installer en ligne de commande sur mon serveur Debian (squeeze).

Imaginez les avantages, vous me direz bien sur qu'il existe d'autres moyen de 
synchroniser/partager des fichier. Mais l'intérêt de DropBox est la simplicité et son 
emploie par de nombreuse personnes a ce jour.

Préparation de l'installation
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Prérequis pour cette installation:

- screen
- lynx
- python 2.6
- wget
- Librairie C > 2.4

.. code-block:: bash

    aptitude install screen lynx wget python glibc

Obtenir la dernière version stable du tar pour votre architecture

- x86 pour les architectures 32bits
- x86_64 pour les architectures 64bits

.. code-block:: bash

    wget -O dropbox.tar.gz "http://www.dropbox.com/download/?plat=lnx.x86"
    wget -O dropbox.tar.gz "http://www.dropbox.com/download/?plat=lnx.x86_64"

Choisir un utilisateur pour lancer DropBox, de préférence sans droits root

Par exemple epheo, pour moi

Connectez vous et allez dans son Home

.. code-block:: bash

    su epheo
    cd ~/

Installation
~~~~~~~~~~~~

Vérifiez et de zippez l'archive dans le Home

.. code-block:: bash

    tar -tzf dropbox.tar.gz && tar -xvzf dropbox.tar.gz

Nous avons donc le client DropBox dans ~/.dropbox-dist/

Lancez le dans un screen

.. code-block:: bash

    screen
    ~/.dropbox-dist/dropboxd

Ici premier problème, il nous demande de se connecter sur une page Web afin de se 
connecter.

Copiez l'adresse indiquée,

Sortez du screen avec ctrl+A+D

Accédez a un page Web quelconque via le navigateur CLI Lynx

.. code-block:: bash

    lynx http://lyon-roller.com

Allez ensuite a l'url copiée précédemment avec maj+G (pour Go) et collez l'url

Connectez vous une première fois avec vos identifiants

Puis reconfirmez votre mot de passe une seconde fois (un peu plus bas dans la page)

Quittez lynx (maj+Q)

récupérez ensuite votre screen

.. code-block:: bash

    screen -r

Votre compte doit être normalement lié avec votre machine et les fichiers commencent 
(enfin) a se synchroniser

:)

Nous allons maintenant télécharger un script python permettant de démarrer, stopper et 
connaître l'état de DropBox plus aisément.

- Créer un dossier bin pour accueillir le script
- Télécharger le script
- Lui donner les droits
- Vérifier le status de DropBox

.. code-block:: bash

    mkdir -p ~/bin
    wget -O ~/bin/dropbox.py"http://www.dropbox.com/download?dl=packages/dropbox.py"
    chmod 755 ~/bin/dropbox.py
    ~/bin/dropbox.py status

Si tout va bien, il devrais vous retourner un message du genre:

``Téléchargement de 6 170 fichiers (1,3 Ko/seconde, 69 jours restants)``

(Oui, c'est lent…)

Redémarrez maintenant DropBox a l'aide du script python afin de vérifier que tout fonctionne correctement.

.. code-block:: bash

  ~/bin/dropbox.py stop
  ~/bin/dropbox.py start

Lancer DropBox au démarrage du système
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Pour Debian, le mieux est de créer un script init.d

Voici un exemple de script, remplacez user par votre utilisateur dans la variable DROPBOX_USERS
 
.. code-block:: bash
 
    #!/bin/sh
    # Script de lancement de DropBox
    DROPBOX_USERS="user"
    
    DAEMON=.dropbox-dist/dropbox
    
    start() {
        echo "Démarrage de dropbox..."
        for dbuser in $DROPBOX_USERS; do
            HOMEDIR=`getent passwd $dbuser | cut -d: -f6`
            if [ -x $HOMEDIR/$DAEMON ]; then
                HOME="$HOMEDIR" start-stop-daemon -b -o -c $dbuser -S -u $dbuser -x $HOMEDIR/$DAEMON
            fi
        done
    }
    
    stop() {
        echo "Arrêt de dropbox..."
        for dbuser in $DROPBOX_USERS; do
            HOMEDIR=`getent passwd $dbuser | cut -d: -f6`
            if [ -x $HOMEDIR/$DAEMON ]; then
                start-stop-daemon -o -c $dbuser -K -u $dbuser -x $HOMEDIR/$DAEMON
            fi
        done
    }
    
    status() {
        for dbuser in $DROPBOX_USERS; do
            dbpid=`pgrep -u $dbuser dropbox`
            if [ -z $dbpid ] ; then
                echo "dropboxd n'est pas lancé pour USER $dbuser: "
            else
                echo "dropboxd est lancé pour l'utilisateur USER $dbuser: (pid $dbpid)"
            fi
        done
    }
    
    case "$1" in
    
        start)
            start
            ;;
    
        stop)
            stop
            ;;
    
        restart|reload|force-reload)
            stop
            start
            ;;
    
        status)
            status
            ;;
    
        *)
            echo "Usage: /etc/init.d/dropbox {start|stop|reload|force-reload|restart|status}"
            exit 1
    
    esac
    
    exit 0

Creer un script dans /etc/init.d/


.. code-block:: bash

    vi /etc/init.d/dropbox

Collez le script ci-dessus après modification

Enregistrez et fermez avec ctrl+x

Pour les autres distrib, une solution générale un peu plus “crade” consisterai a ajouter une crontab.

.. code-block:: bash

    crontab -e
    @reboot $HOME/.dropbox-dist/dropboxd

Post-installation
~~~~~~~~~~~~~~~~~

Maintenant que tout fonctionne il peu être intéressant de déplacer le dossier par 
défaut de DropBox

la solution qui m'a paru la plus simple et de créer un lien symbolique

- Stoppez DropBox
- Déplacez le dossier
- Créez un lien symbolique vers son ancien emplacement (home)
- Redémarrez DropBox

.. code-block:: bash

    ~/bin/dropbox.py stop
    mv ~/Dropbox /votre/nouveau/dossier
    ln -s /votre/nouveau/dossier/Dropbox ~/
    ~/bin/dropbox.py start

Liste des problèmes et améliorations envisageable
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Vous ne pouvez/voulez pas installer lynx
-> Créez un tunnel SSH SOCKS a partir d'un autre PC vers votre serveur

.. code-block:: bash

    ssh -D 9999 nom_dutilisateur@ipduserveur

Activez le proxy SOCKS dans votre navigateur avec host= localhost et port = 9999

Puis inscrivez vous normalement

DropBox envoie sans arrêt des paquets sur le port 17500
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

(et ça me saoule, mon pare-feux me fait la gueule)

Oui, DropBox synchronise aussi en LAN via le port 17500.

Et bien entendu, pas d'option à décocher dans un fichier de conf, ce serait trop beau.

En revanche, un patch python oui :)

Il faut commencer par installer pyDropboxValues.py avec dropbox.py (dans le dossier bin)

.. code-block:: bash

    wget -O ~/bin/pyDropboxValues.py "http://dl.dropbox.com/u/340607/pyDropboxValues.py"
    chmod +x ~/bin/pyDropboxValues.py && ~/bin/pyDropboxValues.py

Il devrait maintenant afficher une liste de config de DropBox. C'est normal, on passe a 
la suite:

Dans l'ordre:

- Télécharger le patch dans le dossier DropBox
- Stopper DropBox
- Backup er pyDropboxValues.py
- Appliquer le correctif
- Relancer DropBox

.. code-block:: bash

    wget -O ~/bin/dropbox_set_lansync.py "http://dl.dropbox.com/u/340607/dropbox_set_lansync.py"
    ~/bin/dropbox.py stop
    cp ~/bin/pyDropboxValues.py ~/bin/pyDropboxValues.py.bak
    chmod +x ~/bin/dropbox_set_lansync.py && ~/bin/dropbox_set_lansync.py off
    ~/bin/dropbox.py start

Et c'est tout bon