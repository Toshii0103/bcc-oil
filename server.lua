-----------------------------------------Pulling Essentials-------------------------------------------------------------------------
local VORPcore = {}
TriggerEvent("getCore", function(core)
  VORPcore = core
end)
local VORPInv = {}
VORPInv = exports.vorp_inventory:vorp_inventoryApi()
local BccUtils = exports['bcc-utils'].initiate()
local discord = BccUtils.Discord.setup(Config.WebhookLink, 'BCC Oil', 'https://gamespot.com/a/uploads/original/1179/11799911/3383938-duck.jpg')

--------- Oil Mission Payout Handler -------------
RegisterServerEvent('bcc:oil:PayoutOilMission', function(Wagon)
  local _source = source
  local Character = VORPcore.getUser(_source).getUsedCharacter
  local param = { ['charidentifier'] = Character.charIdentifier, ['identifier'] = Character.identifier, ['levelincrease'] = Config.LevelIncreasePerDelivery }
  exports.oxmysql:execute('UPDATE oil SET `manager_trust`=manager_trust+@levelincrease WHERE charidentifier=@charidentifier AND identifier=@identifier', param) --increase your level in database table manager_trust by what is set in the config
  exports.oxmysql:execute("SELECT manager_trust FROM oil WHERE charidentifier=@charidentifier AND identifier=@identifier", param, function(result)
    for k, v in pairs(Config.OilCompanyLevels) do --for loop in the table in config
      if result[1].manager_trust >= v.level and result[1].manager_trust < v.nextlevel then
        if Wagon == 'oilwagon02x' then --if the variable then
          Character.addCurrency(0, Config.BasicOilDeliveryPay + v.payoutbonus) break -- Add money basepay + paybonus and break loop so it only adds the money once
        elseif Wagon == 'armysupplywagon' then --if the variable then
          Character.addCurrency(0, Config.SupplyDeliveryBasePay + v.payoutbonus) break --base pay plus paybonus break loop
        end
      elseif result[1].manager_trust < v.level then
        if Wagon == 'oilwagon02x' then --if variable then
          Character.addCurrency(0, Config.BasicOilDeliveryPay) break --gives you the set base pay then breaks loop
        elseif Wagon == 'armysupplywagon' then
          Character.addCurrency(0, Config.SupplyDeliveryBasePay) break
        end
      end
    end
  end)
end)

-------- Robbery Payout Handler --------
RegisterServerEvent('bcc-oil:RobberyPayout', function()
  local _source = source --gets players source
  local Character = VORPcore.getUser(_source).getUsedCharacter --checks the char used
  local param = { ['charidentifier'] = Character.charIdentifier, ['identifier'] = Character.identifier, ['levelincrease'] = Config.LevelIncreasePerDelivery, ['managelevdecrease'] = Config.OilCompanyLevelDecrease }
  exports.oxmysql:execute("SELECT manager_trust FROM oil WHERE charidentifier=@charidentifier AND identifier=@identifier", param, function(result) --selects the trust value in db
    if result[1].manager_trust > 0 then --if trust is greater than 0 then
      exports.oxmysql:execute('UPDATE oil SET `manager_trust`=manager_trust-@managelevdecrease WHERE charidentifier=@charidentifier AND identifier=@identifier', param) --removes manager trust levels
    end
  end)
  exports.oxmysql:execute('UPDATE oil SET `enemy_trust`=enemy_trust+@levelincrease WHERE charidentifier=@charidentifier AND identifier=@identifier', param) --increase your level in database table manager_trust by what is set in the config
  exports.oxmysql:execute("SELECT enemy_trust FROM oil WHERE charidentifier=@charidentifier AND identifier=@identifier", param, function(result) --selects enemy trust from db and creates a funciton to run
    for k, v in pairs(Config.CriminalLevels) do --for loop in the table in config
      if result[1].enemy_trust >= v.level and result[1].enemy_trust < v.nextlevel then
        Character.addCurrency(0, Config.StealOilWagonBasePay + v.payoutbonus) break --pays base pay + bonus pay breaks loop
      elseif result[1].enemy_trust < v.level then
        Character.addCurrency(0, Config.StealOilWagonBasePay) break --just pays base pay and breaks loop
      end
    end
  end)
end)

--Cooldown Event
local wagonrobcooldown, oilcorobcooldown = false, false
RegisterServerEvent('bcc-oil:CrimCooldowns', function(missiontype)
  local Character = VORPcore.getUser(source).getUsedCharacter
  if missiontype == 'wagonrob' then
    if not wagonrobcooldown then
      TriggerClientEvent('bcc-oil:RobOilWagon', source)
      discord:sendMessage(Config.Language.RobberyTitle, Config.Language.Robbery_desc2 .. tostring(Character.charIdentifier))
      wagonrobcooldown = true
      Wait(Config.RobOilWagonCooldown)
      wagonrobcooldown = false
    else
      VORPcore.NotifyRightTip(source, Config.Language.Cooldown, 4000)
    end
  elseif missiontype == 'corob' then
    if not oilcorobcooldown then
      TriggerClientEvent('bcc-oil:RobOilCo', source)
      discord:sendMessage(Config.Language.RobberyTitle, Config.Language.Robbery_desc .. tostring(Character.charIdentifier))
      oilcorobcooldown = true
      Wait(Config.RobOilCoCooldown)
      oilcorobcooldown = false
    else
      VORPcore.NotifyRightTip(source, Config.Language.Cooldown, 4000)
    end
  end
end)

RegisterServerEvent('bcc-oil:OilCoRobberyPayout', function(fillcoords2)
  local _source = source
  local Character = VORPcore.getUser(_source).getUsedCharacter
  if fillcoords2.rewards.itemspayout then --if option is true then
    Character.addCurrency(0, fillcoords2.rewards.cashpayout) --adds money
    for k, v in pairs(fillcoords2.rewards.items) do --creates a for loop set in the rewards.items table(this will run this code once per table)
      VORPInv.addItem(_source, v.item, v.count)
    end
  else --else the option is not true then
    Character.addCurrency(0, fillcoords2.rewards.cashpayout) --just adds cash
  end
end)

------Database Area------
---------Creates DataBase -----------
CreateThread(function()
  exports.oxmysql:execute([[CREATE TABLE if NOT EXISTS `oil` (
    `identifier` varchar(50) NOT NULL,
    `charidentifier` int(11) NOT NULL,
    `manager_trust` int(100) NOT NULL DEFAULT 0,
    `enemy_trust`  int(100) NOT NULL DEFAULT 0,
    `oil_wagon` varchar(50) NOT NULL DEFAULT 'none',
    `delivery_wagon` varchar(50) NOT NULL DEFAULT 'none',
    UNIQUE KEY `charidentifier` (`charidentifier`))
  ]])
end)

------- Checks if player exists in db if not it adds ------
RegisterServerEvent('bcc:oil:DBCheck', function()
  local _source = source
  local Character = VORPcore.getUser(_source).getUsedCharacter
  local param = { ['charidentifier'] = Character.charIdentifier, ['identifier'] = Character.identifier }
  --------The if you exist in db code was pulled from vorp_banking and modified ----------------
  exports.oxmysql:execute("SELECT identifier, charidentifier FROM oil WHERE identifier = @Playeridentifier AND charidentifier = @CharIdentifier", { ["@Playeridentifier"] = Character.identifier, ["CharIdentifier"] = Character.charIdentifier }, function(result)
    if not result[1] then
      exports.oxmysql:execute("INSERT INTO oil ( `charidentifier`,`identifier` ) VALUES ( @charidentifier,@identifier )", param) --If player is not in db this will create him in the db
    end
  end)
end)

------------------------------------- Handles the buying, selling, and spawning of wagons ---------------------------------------------
local wagoninspawn = false
RegisterServerEvent('bcc:oil:WagonManagement', function(type, action)
  local _source = source --sets _source to source. Unsure why but the notifies would not work without doing this
  local Character = VORPcore.getUser(_source).getUsedCharacter --checks the char used
  --------- If wagon type set in menusetup is oilwagon then-----------
  if type == 'oilwagon' then
    local param = { ['charidentifier'] = Character.charIdentifier, ['identifier'] = Character.identifier, ['oilwagon'] = 'oilwagon02x' }
    exports.oxmysql:execute("SELECT oil_wagon FROM oil WHERE charidentifier=@charidentifier AND identifier=@identifier", param, function(result) --gets oil_wagon from the players database
      ---------If action from menusetup is buy then
      if action == 'buy' then
        if result[1].oil_wagon == 'none' then --since the default value is none if you dont own a wagon then
          if Character.money >= Config.OilWagon.price then --checks if you have more money than needed if so then
            Character.removeCurrency(0, Config.OilWagon.price)
            discord:sendMessage(Config.Language.BoughtTitle, Config.Language.bought_desc2 .. tostring(Character.charIdentifier))
            exports.oxmysql:execute("UPDATE oil SET `oil_wagon`=@oilwagon WHERE charidentifier=@charidentifier AND identifier=@identifier", param) --adds the oil wagon to the players database row
            VORPcore.NotifyRightTip(_source, Config.Language.OilWagonBought, 4000) --prints on screen
          else
            VORPcore.NotifyRightTip(_source, Config.Language.NotEnoughCash, 4000) --else you do not have enough money prints on screen
          end
        else --if its anything besides none (you own a wagon) then
          VORPcore.NotifyRightTip(_source, Config.Language.OilWagonAlreadyBought, 4000) --only prints on screen
        end
        ---------Elseif action from menusetup is sell then ---------------------
      elseif action == 'sell' then
        if result[1].oil_wagon == 'none' then --will return none if you do not own a wagon. then
          VORPcore.NotifyRightTip(_source, Config.Language.NoWagontoSell, 4000) --prints on screen
        elseif result[1].oil_wagon == 'oilwagon02x' then --if you do own the oil wagon then
          local param2 = { ['charidentifier'] = Character.charIdentifier, ['identifier'] = Character.identifier, ['oilwagon'] = 'none' }
          exports.oxmysql:execute("UPDATE oil SET `oil_wagon`=@oilwagon WHERE charidentifier=@charidentifier AND identifier=@identifier", param2) --will change the oil_wagon column of the player back to default vale of none
          Character.addCurrency(0, Config.OilWagon.sellprice)
          discord:sendMessage(Config.Language.SoldTitle, Config.Language.sold_desc .. tostring(Character.charIdentifier))
          VORPcore.NotifyRightTip(_source, Config.Language.WagonSold, 4000) --prints on screen
        end
        -------------Elseif action from menusetup is spawn then ----------------------
      elseif action == 'spawn' then
        if wagoninspawn == false then --checks if the wagoninspawn variable is false
          if result[1].oil_wagon == 'none' then --will return none if you do not own a wagon. then
            VORPcore.NotifyRightTip(_source, Config.Language.NoWagonOwned, 4000) --prints on screen
          elseif result[1].oil_wagon == 'oilwagon02x' then --if you do own the oil wagon then
            discord:sendMessage(Config.Language.DeliveryMissionTitle, Config.Language.Delivery_desc .. tostring(Character.charIdentifier))
            wagoninspawn = true --Sets variable to true so that no more wagons can spawn until the bcc:oil:WagonHasLeftSpawn event has ran and reset it
            TriggerClientEvent('bcc:oil:PlayerWagonSpawn', _source, 'oilwagon02x')
          end
        else
          VORPcore.NotifyRightTip(_source, Config.Language.WagonInSpawnLocation, 4000)
        end
      end
    end)
  elseif type == 'supplywagon' then
    local param = { ['charidentifier'] = Character.charIdentifier, ['identifier'] = Character.identifier, ['oilwagon'] = 'armysupplywagon' }
    exports.oxmysql:execute("SELECT delivery_wagon FROM oil WHERE charidentifier=@charidentifier AND identifier=@identifier", param, function(result) --gets oil_wagon from the players database
      ---------If action from menusetup is buy then
      if action == 'buy' then
        if result[1].delivery_wagon == 'none' then --since the default value is none if you dont own a wagon then
          if Character.money >= Config.SupplyWagon.price then --checks if you have more money than needed if so then
            Character.removeCurrency(0, Config.SupplyWagon.price)
            discord:sendMessage(Config.Language.BoughtTitle, Config.Language.bought_desc .. tostring(Character.charIdentifier))
            exports.oxmysql:execute("UPDATE oil SET `delivery_wagon`=@oilwagon WHERE charidentifier=@charidentifier AND identifier=@identifier", param) --adds the oil wagon to the players database row
            VORPcore.NotifyRightTip(_source, Config.Language.SupplyWagonBought, 4000) --prints on screen
          else
            VORPcore.NotifyRightTip(_source, Config.Language.NotEnoughCash, 4000) --else you do not have enough money prints on screen
          end
        else --if its anything besides none (you own a wagon) then
          VORPcore.NotifyRightTip(_source, Config.Language.SupplyWagonAlreadyBought, 4000) --only prints on screen
        end
        ---------Elseif action from menusetup is sell then ---------------------
      elseif action == 'sell' then
        if result[1].delivery_wagon == 'none' then --will return none if you do not own a wagon. then
          VORPcore.NotifyRightTip(_source, Config.Language.NoWagontoSell, 4000) --prints on screen
        elseif result[1].delivery_wagon == 'armysupplywagon' then --if you do own the oil wagon then
          local param2 = { ['charidentifier'] = Character.charIdentifier, ['identifier'] = Character.identifier, ['oilwagon'] = 'none' }
          exports.oxmysql:execute("UPDATE oil SET `delivery_wagon`=@oilwagon WHERE charidentifier=@charidentifier AND identifier=@identifier", param2) --will change the oil_wagon column of the player back to default vale of none
          Character.addCurrency(0, Config.SupplyWagon.sellprice)
          discord:sendMessage(Config.Language.SoldTitle, Config.Language.sold_desc2 .. tostring(Character.charIdentifier))
          VORPcore.NotifyRightTip(_source, Config.Language.WagonSold, 4000)
        end
        -------------Elseif action from menusetup is spawn then ----------------------
      elseif action == 'spawn' then
        if wagoninspawn == false then --checks if the wagoninspawn variable is false
          if result[1].delivery_wagon == 'none' then --will return none if you do not own a wagon. then
            VORPcore.NotifyRightTip(_source, Config.Language.NoWagonOwned, 4000) --prints on screen
          elseif result[1].delivery_wagon == 'armysupplywagon' then --if you do own the oil wagon then
            wagoninspawn = true
            discord:sendMessage(Config.Language.DeliveryMissionTitle, Config.Language.Delivery_desc2 .. tostring(Character.charIdentifier))
            TriggerClientEvent('bcc:oil:PlayerWagonSpawn', _source, 'armysupplywagon')
          end
        else
          VORPcore.NotifyRightTip(_source, Config.Language.WagonInSpawnLocation, 4000)
        end
      end
    end)
  end
end)

--------------Handles making sure the wagon has left the spawn location before allowing a new one to spawn/returend too -------------
RegisterServerEvent('bcc-oil:WagonInSpawnHandler', function(inspawn)
  if inspawn then
    wagoninspawn = true
  else
    wagoninspawn = false
  end
end)

--This handles the version check
BccUtils.Versioner.checkRelease(GetCurrentResourceName(), 'https://github.com/BryceCanyonCounty/bcc-oil')