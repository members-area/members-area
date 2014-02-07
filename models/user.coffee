bcrypt = require 'bcrypt'

module.exports = (sequelize, DataTypes) ->
  return sequelize.define 'User',
    email:
      type: DataTypes.STRING
      allowNull: false
      unique: true
      validate: {isEmail:true}

    username:
      type: DataTypes.STRING
      allowNull: false
      unique: true

    password:
      type: DataTypes.STRING
      allowNull: false

    paidUntil:
      type: DataTypes.DATE
      allowNull: true

    fullname:
      type: DataTypes.STRING
      allowNull: true

    address:
      type: DataTypes.TEXT
      allowNull: true

    approved:
      type: DataTypes.DATE
      allowNull: true

    meta:
      type: DataTypes.TEXT
      allowNull: false
