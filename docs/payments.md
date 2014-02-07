Payments
========

A Payment is a declaration that a User has made a payment; these may be
automatically generated from the [Transaction][] or an external source
(GoCardless); or could be manually entered - e.g. by a Trustee.

If a Payment was generated from a Transaction then it should be linked
to that transaction.

Fields
------

userId: foreign, required
transactionId: foreign, optional
type: string (CASH, GC, STO, BGC, PAYPAL, OTHER)
amount: integer (pence)
when: date
periodFrom: date (the start of the period this payment covers)
periodCount: integer (number of {months} from periodFrom this covers)
meta: JSON

[Transaction]: transactions.md
