module.exports = (sequelize, DataTypes) ->
  return sequelize.define 'Role',
    name:
      type: DataTypes.STRING
      allowNull: false
      unique: true
      validate: {isEmail:true}

    meta:
      type: DataTypes.TEXT
      allowNull: false
