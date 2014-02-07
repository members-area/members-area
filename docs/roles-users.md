Roles-Users
===========

Links between [Users][] and [Roles][].

A user doesn't have the role unless `approved` is not `NULL` and
`rejected` is `NULL`.

Fields
------

 - userId
 - roleId
 - approved: date, optional
 - rejected: date, optional
 - rejectionReason: string, optional
 - meta: JSON

Meta fields
-----------

 - approvals, array of `{userId, role}` of people who approved this

[Users]: users.md
[Roles]: roles.md
