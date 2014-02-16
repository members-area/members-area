friendRoleId = 1
trusteeRoleId = 2
supporterRoleId = 3
memberRoleId = 4

exports.friend =
  id: friendRoleId
  name: 'Friend'
  meta:
    base: true
    requirements: [
      {
        type: 'approval'
        roleId: trusteeRoleId
        count: 1
      }
    ]

exports.trustee =
  id: trusteeRoleId
  name: 'Trustee'
  meta:
    owner: true
    requirements: [
      {
        type: 'role'
        roleId: memberRoleId
      }
      {
        type: 'text'
        text: "voted in by the membership"
      }
      {
        type: 'approval'
        roleId: 20
        count: 3
      }
    ]

exports.supporter =
  id: supporterRoleId
  name: 'Supporter'
  meta:
    requirements: [
      {
        type: 'role'
        roleId: friendRoleId
      }
      # XXX: Change this to something that detects payment
      {
        type: 'text'
        text: 'A payment has been made'
      }
      {
        type: 'approval'
        roleId: trusteeRoleId
        count: 1
      }
    ]

exports.member =
  id: memberRoleId
  name: 'Member'
  meta:
    requirements: [
      {
        type: 'role'
        roleId: friendRoleId
      }
      {
        type: 'role'
        roleId: supporterRoleId
      }
      {
        type: 'approval'
        roleId: trusteeRoleId
        count: 3
      }
      {
        type: 'text'
        text: "Legal name proved to a trustee"
      }
      {
        type: 'text'
        text: "Home address proved to a trustee"
      }
    ]
