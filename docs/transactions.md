Transactions
============

Transactions are basically just lines from bank statements imported
into the system.

When a transaction is input it can be parsed by automatic filters and
from this [Payments][] could be generated and Users can be updated.

Fields
------

bankId: string (sort code)
accountId: string (account number)
transactionType: string (OTHER, DIRECTDEP)
when: date
amount: integer (pence)
description: string
type: string (BGC, BBP, STO, ...; if it can be extracted from the description)

[Payments]: payments.md
