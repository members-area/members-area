module.exports = (sequelize, DataTypes) ->
  return sequelize.define 'RoleUser',
    approved:
      type: DataTypes.DATE
      allowNull: true

    rejected:
      type: DataTypes.DATE
      allowNull: true

    rejectionReason:
      type: DataTypes.TEXT
      allowNull: true

    meta:
      type: DataTypes.TEXT
      allowNull: false
      defaultValue: JSON.stringify {}
  ,
    tableName: 'RolesUsers'
