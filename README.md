# dnssec
This project is implementing a DNSSEC system for a TLD.

It has elements to relating to a proper key ceremony as well as to running a server as a "signer" as bump-in-the-wire.

The idea is to use simple components that are easy and cheap to find. This makes it easy and cheap to create a test lab, as it can be done on virtual machines entirely.

The project started in December 2015.

The keyceremony subdirectory has tools and perl/bash/sh-scripts for use at the keyceremony itself.

The signer subdirectory has the same, but for the signer.

The documentation subdirectory has various documentation.
