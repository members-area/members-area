Roles
=====

You can define your own roles and their dependencies. Users can have
many roles. Roles can represent many things, for example at [So Make
It][] we use the following roles:

(Note that roles marked with an asterisk (\*) are textual only and
cannot be automatically checked by the software.)

### Friend

The base role that people get when they sign up (sometimes referred to
as "associate membership").

Requirements:

 - 1 **Trustee**'s approval

Grants:

 - Login

### Supporter

Someone who has had a payment registered via the members area (either
via a cash payment to a trustee or they've set up a subscription -
GoCardless or Standing Order).

Requirements:

 - Role: **Friend**

### Member

Someone who is on our [Register of Members][]

Requirements:

 - Roles: [**Friend**, **Supporter**]
 - Quorum of **Trustee**'s approval
 - Legal name proved to a **Trustee**\*
 - Home address proved to a **Trustee**\*

### Keyholder

A Member who can open the space.

Requirements:

 - Roles: [**Member**]
 - Must be approved (vouched for) by 5 **Keyholders**
    - Attending the space a good few times and building up some rapport
      is a good way of acheiving this
 - Subscription up to date
 - No demerits\*
 - Must be approved by 1 **Trustee**

### Admin

Someone who is allowed to view member's subscription statuses, contact
details, etc - for example a Member tasked with chasing up subscription
payments.

Requirements:

 - Roles: [**Member**]
 - Quorum of **Trustee**'s approval

Grants:

 - View everything
 - Create/modify/delete payments

### Trustee

A Member who is also a director of So Make It Ltd; they get access to
everything.

Requirements:

 - Roles: [**Member**]
 - Must be voted in by the membership\*
 - Quorum of **Trustee**'s approval

Grants:

 - Everything

Requesting a role
-----------------

When you meet the automatically verifiable requirements of a role
(other roles and subscription status or payments, basically) you can
request a role.

Then if your request requires approval you'll go into the 'Approve Me'
list where people with the relevant roles can approve your request.
Members with multiple roles (e.g. **Member** and **Trustee**) count
against each role that requires approval (e.g. **Keyholder** above only
requires 5 people to approve the request, not 6).

People giving approval to your request are declaring that the other
requirements of the role have been met.

Approvals are public.

Once all requirements have been met, you are granted the role.

Fields
------

 - name: string

Meta
----

 - base: true if this is the basic role
 - owner: true if this is the owner role
