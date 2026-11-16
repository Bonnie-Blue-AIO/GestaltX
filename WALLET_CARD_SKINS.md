# Wallet Card Skins (fork)

Prototype: apply custom Apple Wallet card artwork via GestaltX `worse_query` / `acquirePath` on `/var/mobile/Library/Passes/Cards/<id>.pkpass`.

- Artwork sizes/names adapted from AirCard-iOS (MIT).
- **Restore Original** restores the first GestaltX backup for that card.
- Live Apple Pay card ID scanning (Airlift syslog) is **not** included — paste a card ID or Refresh the Passes folder listing.
- If opening `/var/mobile/Library/Passes/Cards` fails on device, this path may still need Airlift; boot-loop risk for cache PNG/PDF writes is low.

Fork marketing version: **1.1.1-wallet** (build 11140104).
