# RebornAP: connects Pokémon Reborn to the Archipelago "Pokemon Reborn Client" (protocol: see client.py).
# Install: copy this file into <Reborn>/patch/Mods/ (loaded by Scripts/ScriptLoader.rb after the game scripts).
#
# A location is the event command that gives the vanilla item: "map:event:page:command" (data/checks.json
# "game_keys"). pbExecuteScript records which script runs; the give functions (pbItemBall, pbReceiveItem,
# $PokemonBag.pbStoreItem) and the badge line ($Trainer.badges[n]=true) then send the check instead.
# Passwords come from the yaml only: set at Ame's question in the intro train, the PC menu is hidden.
require 'socket'
require 'json'

class PokemonGlobalMetadata # saved with the game
  attr_accessor :ap_item_index     # index of the next AP item to give
  attr_accessor :ap_location_keys  # "map:event:page:command" => true: the AP locations, known while offline too
  attr_accessor :ap_checked        # ids (keys while offline) of the locations collected, sent at each connection
  attr_accessor :ap_seed           # seed last connected to
  attr_accessor :ap_story_gates    # the story_gates option
  attr_accessor :ap_withheld       # badge indexes of the leaders beaten whose story effects wait for the badge
  attr_accessor :ap_fights_won     # badge indexes of the leaders beaten
  attr_accessor :ap_gym_story      # badge index => the gym's own story value (gym_view)
  attr_accessor :ap_railnet_return # [map, x, y, direction] to go back to after the Railnet cutscene
  attr_accessor :ap_railnet_notice # RAILNET_NOTICE still to show
end

module RebornAP
  HOST = "127.0.0.1"
  PORT = 47630
  PROTOCOL_VERSION = 7
  RETRY_SECONDS = 3
  LOG_FILE = "RebornAP.log"
  BADGE_NAMES = ["Volt Badge", "Canopy Badge", "Cocoon Badge", "Omen Badge", "Blight Badge", "Rime Badge",
                 "Standard Badge", "Millennium Badge", "Eclipse Badge", "Strike Badge", "Cinder Badge", "Gravity Badge",
                 "Suspension Badge"]
  # Leaders for story_gates badge / both, by badge index:
  # - event: [map, event] of the fight; switch: the story switch it sets after the fight
  # - point: when the gym opens in the story (from there the badge item opens the story, story_gates badge)
  # - after: what the event sets after a win, [[:switch / :var, id, value]...]
  # - door: [map, event, open page, locked page] of the gym door the switch locks, or nil
  # - fight: the fight pages (kept while the story moved on without the fight); win: the page after a win
  # - triggers: events of the same map that start the fight (kept on their first page with it)
  # - gym, when the gym has its own story steps (gym_view): [maps or [map, event], default value, value from which the
  #   steps go on after the win, optional [[:switch / :var, id]...] that read unset there]
  # - notice: message shown when the badge arrives once the point is reached
  Leader = Struct.new(:event, :switch, :point, :after, :door, :fight, :win, :triggers, :gym, :notice) do
    # [:var, id, value] of `after`: the story variable (gyms with their own steps)
    def story_var = after.find { |kind, _, _| kind == :var }
  end
  HELD_GATES = ["badge", "both"].freeze # story_gates where a win without the badge is held back
  LEADERS = {
    # Julia: S62 First Badge, opens on S61 Gym Open
    0 => Leader.new([351, 1], 62, -> { $game_switches[61] }, [[:switch, 62, true]], nil, [0], 1, []),
    # Florinia: S64 Second Badge, opens at E2 Story 19 (Amaria's scene in Obsidia Ward). After: S586 Pulse App, S592
    # PULSE 5, E3 Story = 1 (Jasper Ward), S64. The door of the Onyx Trainers' School is "Locked." on S64
    1 => Leader.new([127, 2], 64, -> { $game_variables[56] >= 19 },
                    [[:switch, 586, true], [:switch, 592, true], [:var, 77, 1], [:switch, 64, true]], [125, 2, 0, 1],
                    [0], 1, []),
    # Shelly: S134 Fourth Gym Done, opens at E4 Story 18 (she waits in Lapis Gym). After: E4 Story = 19, S134
    2 => Leader.new([182, 101], 134, -> { $game_variables[92] >= 18 }, [[:var, 92, 19], [:switch, 134, true]], nil,
                    [0], 1, []),
    # Shade: S139 Fifth Badge, opens at E5 Story 28 (Charlotte asks to see him; the generators stay the gym's route).
    # After: S139, which starts the Railnet cutscene (RAILNET_SCENE). Page 1 is an autorun: page 2, empty, after a win
    3 => Leader.new([197, 30], 139, -> { $game_variables[104] >= 28 }, [[:switch, 139, true]], nil, [0], 2, []),
    # Aya (fight on page 1, page 0 is Fern's): S179 Seventh Badge, opens at E7 Story 12 (Cain opens the gate to
    # Byxbysion). After: S179, E7 Story = 16 (Cain's fight). Own steps: Ace of Diamonds 13, Lana's cutscene 14, Fern 15
    4 => Leader.new([224, 2], 179, -> { $game_variables[118] >= 12 }, [[:switch, 179, true], [:var, 118, 16]], nil,
                    [0, 1], 2, [], [[223, 224, [209, 87]], 15, 16]),
    # Serra: S207 Eighth Badge, opens at E8 Escort Bandaid 13 (Laura asks for the Herbal Extract) or E8 Story 14.
    # S207 moves the PokéMart that sells it to the Chrysolia Region (notice). After: S207, E8 Story = 22. Own steps
    # 14-21: the salon, the house, the Mirror Arena, El and Bennett leaving. V149 E9 Story and S254 Ninth Badge read
    # unset there: their empty pages (Noel beaten first) would hide those scenes after a late win
    5 => Leader.new([506, 55], 207, -> { $game_variables[748] >= 13 || $game_variables[123] >= 14 },
                    [[:switch, 207, true], [:var, 123, 22]], nil, [0], 1, [],
                    [[506, [239, 19], [239, 20], [239, 25], [239, 26], [239, 27], [239, 32], [239, 33], [271, 186],
                      [271, 187], [271, 188], [271, 189], [271, 191], [271, 192]], 18, 19, [[:var, 149], [:switch, 254]]],
                    "Word is that the Spinel Town PokéMart has reappeared in the Chrysolia Region."),
    # Noel (fight on page 2): S254 Ninth Badge, opens at E9 Story 18. After: S504 off, S254, E9 Story = 19. The cove
    # (Noel, Anna, Shelly the referee) stays at 18 until his gift sets 19: nobody leaves during the fight's words
    6 => Leader.new([232, 12], 254, -> { $game_variables[149] >= 18 },
                    [[:switch, 504, false], [:switch, 254, true], [:var, 149, 19]], nil, [2], 3, [],
                    [[[232, 11], [232, 12], [232, 13]], 18, 18]),
    # Radomus (page 1, an autorun started by the tiles ev39/44-46, is the fight): S283 Tenth Badge, opens at E10 Story
    # 27 (doors of the challenge hall). After: S283, E10 Story = 42 (then Elias: ELIAS_SALON). Own steps 28-41: the
    # chess puzzles (maps 313-318), and Cain in the castle hall, who would vanish in front of the player (GYM_LEAVE)
    7 => Leader.new([315, 35], 283, -> { $game_variables[150] >= 27 },
                    [[:switch, 283, true], [:var, 150, 42]], nil, [0, 1], 2, [39, 44, 45, 46],
                    [[313, 314, 315, 316, 317, 318, [293, 20]], 40, 41]),
    # Luna: S422 11th Badge (Agate City Checkpoint), opens on S435 Sanctum Chains (Ace of Hearts beaten). Her fight
    # stays: it is the goal
    8 => Leader.new([350, 2], 422, -> { $game_switches[435] }, [[:switch, 422, true]], nil, [0], 1, []),
  }
  # Events that read the leader's switch as off while its fight is kept (story_gates badge): Yureyu Power Plant's
  # lights and Factory field stay dark and flickering until Shade's fight, as in vanilla
  FIGHT_VIEW = { [197, 4] => 3, [198, 3] => 3, [198, 16] => 3 }
  # Vanhanen Castle: its doors fade in to a blackout tone once S283 Tenth Badge is on (end of Radomus' fight). Lit
  # instead once the castle reopens (E11 Story >= 5) and, story_gates badge, while S283 came from the badge
  # (castle_lit?)
  CASTLE_MAPS = [292, 293, 313, 314, 315, 316, 317, 318]
  CASTLE_DARK = [-187, -187, -119, 187]
  CASTLE_REOPENED = 5
  # [map, event] of a gym's steps => when it leaves them: Cain in the castle hall once Elias starts E11 (E11 Story >= 1)
  GYM_LEAVE = { [293, 20] => -> { $game_variables.__ap_get_variable(159) >= 1 } }
  # Elias (map 293 ev26, autorun on S456 Freeze protect & S283) starts E11. In vanilla the player sets S456 leaving
  # Radomus' room and meets him in the castle salon; an autorun starts wherever the player stands on its map, so when
  # S283 comes from the badge the mod sets S456 once the player is in the salon, not in the entrance hall (call_elias)
  ELIAS_SALON = [293, 14] # map, first row past the entrance hall
  ELIAS_SWITCH = 456
  LEADER_EVENTS = LEADERS.to_h { |n, leader| [leader.event, n] }
  LEADER_TRIGGERS = LEADERS.flat_map { |n, leader| leader.triggers.map { |e| [[leader.event[0], e], n] } }.to_h
  LEADER_DOORS = LEADERS.select { |_, leader| leader.door }.to_h { |n, leader| [leader.door[0, 2], n] }
  # a map (all its events) or [map, event] => badge index of the gym whose own steps it follows
  GYM_EVENTS = LEADERS.select { |_, leader| leader.gym }.flat_map { |n, leader| leader.gym[0].map { |m| [m, n] } }.to_h
  # [map, event] => [badge index, first line of a box => box said instead] while a gym's steps remain (gym_text).
  # Serra's house: with the Rime Badge, the PokéMart already left her roof for the Chrysolia Region
  GYM_TEXTS = {
    [239, 19] => [5, {
      "Honestly, all we can do might be to hope that it" => "Then again, you already carry the Rime Badge, don't you?",
      "As it is, you're welcome to stay here until the" =>
        "In that case, the PokéMart has no reason to stay on my roof. You should find it in the Chrysolia Region.",
    }],
  }
  # Railnet cutscene (map 196 ev26, autorun on S139): in vanilla Shade's fight leaves the player at (26,9) beside it,
  # and it ends with a transfer to Shade, whose autorun sets RAILNET_SHADE; its rocks then block the tunnel. When S139
  # comes from the Omen Badge, the mod plays it once the player is free, on foot and off map 196 (railnet_trip), brings
  # them back where they were instead of to Shade (railnet_return), then shows RAILNET_NOTICE
  RAILNET_SCENE = [196, 26]
  RAILNET_SPOT = [26, 9]
  RAILNET_SHADE = [197, [[:var, 107, 3], [:switch, 156, false], [:switch, 2116, true]]]
  RAILNET_LEADER = 3
  RAILNET_NOTICE = "Word is that Cain is waiting for you at the entrance of Jasper Ward."
  # where Jasper Stairway leaves the player, one row above the tiles that set E6 Story 3 -> 4 (Cain, map 130 ev24)
  CAIN_ENTRANCE = [130, 49..55, 37]
  CAIN_STORY = 107
  # Crystal Key (progressive AP item): the nth copy is CRYSTALPLUG<n>, which replaces the previous one; an event that
  # tests a crystal accepts a higher one (Vanhanen Labyrinth map 292 ev38 tests CRYSTALPLUG1 only)
  CRYSTAL_KEY = :CRYSTALKEY
  CRYSTALS = [:CRYSTALPLUG1, :CRYSTALPLUG2, :CRYSTALPLUG3, :CRYSTALPLUG4]
  CRYSTAL_SCRIPT = /\A\s*\$PokemonBag\.pbQuantity\(:CRYSTALPLUG(\d)\)\s*>\s*0\s*\z/
  BALL_KINDS = ["hidden", "item_ball"]
  BADGE_SCRIPT = /\A\s*\$Trainer\.badges\[(\d+)\]\s*=\s*true\s*\z/
  RECEIVED_TEXT = /received|obtained/i
  OWNED_SCRIPT = /\A\s*\$PokemonBag\.pbQuantity\(:(\w+)\)\s*>\s*0\s*\z/
  # Intro Train, Ame: her first Yes/No choice asks for passwords
  AME = [667, 8]
  # set only at Ame's question: the Grand Hall reads them when the starter is chosen
  START_PASSWORDS = ["eeveepls", "vulpixpls", "freestarter"]
  # Texts about the vanilla item after a give that was a check (the AP message told what was found), and their Yes / No
  # question (answered "No"): Iolia Valley crystals (the Crystal Key decides), Spinel Town Exp. All (asked when the AP
  # Exp. All arrives: EXP_ALL)
  CHECK_TEXTS = {
    [335, 157] => /\AGreen Crystals can now be activated/,
    [335, 158] => /\ABlue Crystals can now be activated/,
    [343, 3] => /\APurple Crystals can now be activated/,
    [242, 42] => /new models|levelling to the point|\ANifty|turn the EXP All on/
  }
  # Exp. All received from AP: the question of the Spinel Town event (S1181 EXP All On, item swapped as it does)
  EXP_ALL = [:EXPALLOFF, :EXPALL, 1181]
  # Repeated give (7th Street Ability Capsule seller, 324 ev12: one more shard each time, 1 to 3): the 2nd, 3rd...
  # gives are checks of their own, game keys "<key>#2", "<key>#3"; once all of them are collected the give is vanilla
  REPEAT_MARK = "#"
  # Hyde (7th Street, trainer) stands on the only tile from which the hidden Exp. Candy XL is picked up, and goes back
  # there at each map load. Once beaten, he moves to `spot` and stays there
  HYDE = { event: [325, 4], spot: [29, 12], end_script: "pbTrainerEnd",
           text: "Aight, aight, I'm movin'... Don't harsh my vibe, buddy." }

  @socket = nil
  @buffer = String.new
  @read_buffer = String.new(capacity: 65536)
  @next_connect = 0
  @ap_ready = false     # the client is connected to the AP server and sent "init"
  @locations = {}       # "map:event:page:command" => location hash from "init"
  @pending_items = {}   # item index => item hash from "items"
  @resync_needed = false
  @scripts = []         # event scripts being run: [map, event, page, first command, last command, list]
  @vanilla = 0          # > 0 while a vanilla give function runs (its inner pbStoreItem is not a location)
  @sent_map = nil       # map id last sent to the client
  @story = nil          # "switches" / "variables" ids from "init" (data/story.json), read for PopTracker
  @sent_story = nil     # their values last sent to the client
  @passwords = nil      # password => value from "init" (exppercent: Exp_Percent or nil)
  @check_event = nil    # [map, event] of the running event once one of its gives sent a check (CHECK_TEXTS)
  @announced = {}       # location id => true: the check showed the player their own item it held (not said again)

  def self.log(text)
    File.open(LOG_FILE, "ab") { |f| f.write("[#{Time.now.strftime('%H:%M:%S')}] #{text}\n") }
  rescue StandardError
  end

  # Called every frame on the overworld.
  def self.update
    pump
    send_map if @socket
    send_story if @socket
    resync if @resync_needed
    give_pending_items
    open_story_gates
    railnet_trip
    railnet_notice
    meet_cain
    call_elias
  rescue StandardError => e
    log("update error: #{e.class}: #{e.message}\n#{e.backtrace.first(5).join("\n")}")
  end

  # --- connection ---

  # connects (every RETRY_SECONDS) and reads what the client sent
  def self.pump
    try_connect if !@socket && Time.now.to_f >= @next_connect
    poll if @socket
  end

  def self.try_connect
    @next_connect = Time.now.to_f + RETRY_SECONDS
    @socket = Socket.tcp(HOST, PORT, connect_timeout: 0.05)
    @buffer = String.new
    @sent_map = nil
    @sent_story = nil
    log("connected to the client")
    send_msg("cmd" => "hello", "version" => PROTOCOL_VERSION)
  rescue StandardError
    @socket = nil
  end

  def self.disconnect
    log("disconnected from the client") if @socket
    @socket.close rescue nil
    @socket = nil
    @ap_ready = false
  end

  def self.send_msg(msg)
    return false unless @socket

    @socket.write(JSON.generate(msg) + "\n")
    true
  rescue StandardError
    disconnect
    false
  end

  def self.poll
    loop do
      chunk = @socket.read_nonblock(65536, @read_buffer, exception: false) # one buffer, not 64 KiB per frame
      break if chunk == :wait_readable
      return disconnect if chunk.nil? # closed by the client

      @buffer << chunk
    end
    while (newline = @buffer.index("\n"))
      line = @buffer.slice!(0..newline).force_encoding(Encoding::UTF_8)
      handle_line(line)
    end
  rescue IOError, SystemCallError
    disconnect
  end

  def self.handle_line(line)
    handle(JSON.parse(line))
  rescue StandardError => e
    log("message not handled: #{e.class}: #{e.message}: #{line[0, 200]}\n#{e.backtrace.first(5).join("\n")}")
  end

  # The client writes the map in the AP data storage: the PopTracker pack opens its tab.
  def self.send_map
    map_id = $game_map && $game_map.map_id
    return if !map_id || map_id == @sent_map

    @sent_map = map_id if send_msg("cmd" => "map", "id" => map_id)
  end

  # The client writes them in the AP data storage: the PopTracker pack shows the missable checks they closed.
  def self.send_story
    return unless @story && $game_switches && $game_variables

    values = {}
    @story["switches"].each { |id| values["S#{id}"] = $game_switches[id] == true }
    @story["variables"].each { |id| values["V#{id}"] = $game_variables[id].is_a?(Integer) ? $game_variables[id] : 0 }
    return if values == @sent_story

    @sent_story = values if send_msg("cmd" => "story", "values" => values)
  end

  def self.handle(msg)
    case msg["cmd"]
    when "init"
      @locations = {}
      @pending_items.clear # the client sends all the items again after "init"
      @story = msg["story"]
      @sent_story = nil
      msg["locations"].each { |loc| loc["keys"].each { |key| @locations[key] = loc } }
      $PokemonGlobal.ap_location_keys = @locations.keys.to_h { |key| [key, true] }
      options = msg["options"] || {}
      $PokemonGlobal.ap_story_gates = options["story_gates"] || "leader"
      @passwords = options["passwords"] || {}
      @ap_ready = true
      apply_passwords(false) if $game_map && $game_map.map_id != AME[0] # Ame sets them in the intro train
      @resync_needed = true
      log("init: #{msg['locations'].length} locations, seed #{msg['seed']}, slot #{msg['slot']}, " \
          "story_gates #{$PokemonGlobal.ap_story_gates}")
      # a save connected to another seed: its item index counts the other seed's items, the new seed's are all due
      seed = msg["seed"].to_s
      if $PokemonGlobal.ap_seed && $PokemonGlobal.ap_seed != seed && ($PokemonGlobal.ap_item_index || 0) > 0
        log("save of seed #{$PokemonGlobal.ap_seed}: the items of seed #{seed} are given from the first")
        $PokemonGlobal.ap_item_index = 0
      end
      $PokemonGlobal.ap_seed = seed
    when "items"
      msg["items"].each { |item| @pending_items[item["index"]] = item }
    when "ap_status"
      @ap_ready = msg["connected"]
      log("AP server #{@ap_ready ? 'connected' : 'disconnected'}")
    end
  end

  # --- passwords ---

  # The yaml decides: the switch of each password sent takes its value (the other passwords are not touched).
  # exppercent: Exp_Percent, nil = off.
  def self.apply_passwords(game_start)
    on = []
    @passwords.each do |name, value|
      next if name == "exppercent" || (START_PASSWORDS.include?(name) && !game_start)

      id = PASSWORD_HASH[name]
      next log("unknown password #{name}") unless id

      $game_switches[id] = value == true
      on << name if value == true
    end
    if @passwords.key?("exppercent")
      percent = @passwords["exppercent"]
      $game_switches[:Percent_Exp_Gains] = !percent.nil?
      $game_variables[:Exp_Percent] = percent if percent
      on << "exppercent #{percent}" if percent
    end
    $game_map.need_refresh = true
    log("passwords#{game_start ? ' (game start)' : ''}: #{on.empty? ? 'none' : on.join(', ')}")
  end

  # [map, event] the interpreter runs (or ran last: it keeps them once the event ended)
  def self.event_of(interpreter)
    [interpreter.instance_variable_get(:@map_id), interpreter.instance_variable_get(:@event_id)]
  end

  # "map:event:page:command", as in checks.json
  def self.key_of(map_id, event_id, page, index) = "#{map_id}:#{event_id}:#{page}:#{index}"

  def self.ame_question?(interpreter, command)
    event_of(interpreter) == AME && command.indent == 0 && command.parameters[0] == ["Yes", "No"]
  end

  # Ame's question: wait until the client sent the passwords (the starter ones must be set before the Grand Hall)
  def self.wait_for_passwords
    return if @ap_ready && @passwords

    log("Ame waits for the client")
    window = Kernel.pbCreateMessageWindow
    # \wtnp[0]: shown at once without waiting for a key (the game's patch download message does the same)
    Kernel.pbMessageDisplay(window, _INTL("Waiting for Archipelago...\\wtnp[0]"), false, tts: false)
    until @ap_ready && @passwords
      Graphics.update
      Input.update
      window.update
      pump
    end
  ensure
    Kernel.pbDisposeMessageWindow(window) if window
  end

  # --- locations ---

  # Where the event script about to run is: [map, event, page, first command, last command, list], or nil.
  def self.script_position(interpreter)
    list = interpreter.instance_variable_get(:@list)
    index = interpreter.instance_variable_get(:@index)
    event_id = interpreter.instance_variable_get(:@event_id)
    map_id = interpreter.instance_variable_get(:@map_id)
    return nil if !list || !index || !event_id || event_id <= 0 || map_id != $game_map.map_id

    event = $game_map.events[event_id]
    return nil unless event

    # the running list, not the current page: the page may change while the event runs
    page = event.event.pages.index { |pg| pg.list.equal?(list) }
    return nil unless page

    first = index
    first -= 1 while first > 0 && list[first].code == 655 # command_355 has moved @index to the last script line
    [map_id, event_id, page, first, index, list]
  end

  def self.ap_key?(key)
    return @locations.key?(key) if @ap_ready

    keys = $PokemonGlobal && $PokemonGlobal.ap_location_keys
    keys.is_a?(Hash) && keys.key?(key)
  end

  # AP location key of the give of `item` by the running script, or nil (vanilla give).
  def self.give_key(item)
    pos = @scripts.last
    return nil if !pos || @vanilla > 0

    map_id, event_id, page, first, last, list = pos
    keys = (first..last).map { |i| [key_of(map_id, event_id, page, i), i] }.select { |key, _| ap_key?(key) }
    return nil if keys.empty?

    # several gives in one script: the line that names the item
    found = keys.find { |_, i| list[i].parameters.join(" ").include?(":#{item}") }
    repeat_key((found || keys.first)[0])
  end

  # Repeated give (REPEAT_MARK): the first of "<key>", "<key>#2", "<key>#3"... not collected yet, nil once all are
  # (vanilla give). Any other give: its key.
  def self.repeat_key(key)
    return key unless ap_key?("#{key}#{REPEAT_MARK}2")

    n = 1
    current = key
    while collected?(current)
      n += 1
      current = "#{key}#{REPEAT_MARK}#{n}"
      return nil unless ap_key?(current)
    end
    current
  end

  def self.badge_key(script)
    pos = @scripts.last
    return nil if !pos || !script.match?(BADGE_SCRIPT)

    key = key_of(*pos[0, 4])
    ap_key?(key) ? key : nil
  end

  def self.run_script(interpreter, script)
    pos = script_position(interpreter)
    @scripts.push(pos)
    @collected = false
    text = script.to_s
    n = pos && LEADER_EVENTS[pos[0, 2]]
    key = !n && badge_key(text)
    owned = pos && text.match(OWNED_SCRIPT)
    owned_key = owned && own_give_key(pos, owned[1])
    crystal = text.match(CRYSTAL_SCRIPT)
    result = if owned_key
               collected?(owned_key)
             elsif crystal
               crystal_level >= crystal[1].to_i
             elsif n
               leader_script(n, text) { yield }
             elsif key
               collect(key)
             else
               yield
             end
    skip_received_text(interpreter) if @collected
    step_aside(pos) if pos && pos[0, 2] == HYDE[:event] && text.strip == HYDE[:end_script]
    result
  ensure
    @scripts.pop
  end

  # Hyde beaten (HYDE): he says he moves and walks to his spot, down then along the row (he faces right, so the player
  # is on his row; if the player came from below, he goes right first)
  def self.step_aside(pos)
    map_id, event_id, = pos
    event = $game_map.events[event_id]
    return if !event || !$game_self_switches[[map_id, event_id, "A"]]

    tx, ty = HYDE[:spot]
    route = if $game_player.x == event.x && $game_player.y == event.y + 1
              [PBMoveRoute::Right, PBMoveRoute::Down]
            else
              [PBMoveRoute::Down] + [event.x > tx ? PBMoveRoute::Left : PBMoveRoute::Right] * (event.x - tx).abs
            end
    Kernel.pbMessage(_INTL(HYDE[:text]))
    pbMoveRoute(event, route)
    pbWait(1) while event.move_route_forcing # the event goes on once he is there
    log("Hyde steps aside to #{[event.x, event.y].inspect} (spot #{[tx, ty].inspect})")
  end

  # Map loaded: Hyde, once beaten, is back on his spot
  def self.event_placed(event, map_id)
    return if [map_id, event.event.id] != HYDE[:event] || !$game_self_switches ||
              !$game_self_switches[[map_id, event.event.id, "A"]]

    event.moveto(*HYDE[:spot])
  end

  # A Show Text box of CHECK_TEXTS, after the event's give sent a check: not said
  def self.skip_text?(map_id, event_id, text)
    rx = CHECK_TEXTS[[map_id, event_id]]
    return false if !rx || @check_event != [map_id, event_id] || !text.to_s.match?(rx)

    log("text skipped after a check: #{text.to_s[0, 40]}")
    true
  end

  # The Yes / No question after a skipped text (Spinel Town Exp. All): "No", without showing it
  def self.skip_choice?(map_id, event_id, choices)
    CHECK_TEXTS.key?([map_id, event_id]) && @check_event == [map_id, event_id] && choices == ["Yes", "No"]
  end

  # An event that gives an item only when the player does not have it yet (Membership Card: "IF SCRIPT
  # $PokemonBag.pbQuantity(:MEMBERSHIPCARD)>0", give in the ELSE branch): the AP item may already be in the bag, which
  # would make the check impossible. The test answers whether the check was sent instead: no -> the event gives (sends
  # the check), yes -> the event acts as if the player had the item. Key of the AP give of `item` in the same page.
  def self.own_give_key(pos, item)
    map_id, event_id, page, = pos
    event = $game_map.events[event_id]
    return nil unless event

    event.event.pages[page].list.each_with_index do |cmd, i|
      next unless [111, 355, 655].include?(cmd.code) && cmd.parameters.join(" ").include?(":#{item})")

      key = key_of(map_id, event_id, page, i)
      return key if ap_key?(key) && i != pos[3]
    end
    nil
  end

  def self.collected?(key)
    checked = ($PokemonGlobal && $PokemonGlobal.ap_checked) || []
    loc = @ap_ready ? @locations[key] : nil
    return checked.include?(key) unless loc

    checked.include?(loc["id"]) || (loc["keys"] & checked).any?
  end

  # A give replaced in a script command ($PokemonBag.pbStoreItem, the badge line) is announced by the event itself in
  # the next commands: sound, then "\PN received 5 Poké Balls!". Skip both: the AP message already played the sound
  # and told what was found.
  def self.skip_received_text(interpreter)
    list = interpreter.instance_variable_get(:@list)
    index = interpreter.instance_variable_get(:@index)
    return unless list && index && [355, 655].include?(list[index].code) # not an IF SCRIPT (command_111)

    se = list[index + 1] && list[index + 1].code == 250 ? list[index + 1] : nil # Play SE
    i = se ? index + 2 : index + 1
    return unless list[i] && list[i].code == 101 && list[i].parameters[0].to_s.match?(RECEIVED_TEXT)

    i += 1
    i += 1 while list[i] && list[i].code == 401 # continuation lines of the text
    interpreter.instance_variable_set(:@index, i - 1) # the interpreter moves on to the next command
    log("vanilla text skipped: #{list[index + 1..i - 1].map(&:code).inspect}")
  end

  # A give hook (pbStoreItem, pbItemBall, pbReceiveItem): the AP check of the running script, else the vanilla give
  def self.give(item, &vanilla_give)
    key = give_key(item)
    key ? collect(key) : vanilla(&vanilla_give)
  end

  def self.vanilla
    @vanilla += 1
    yield
  ensure
    @vanilla -= 1
  end

  # Replaces the vanilla give: sends the check (now, or at the next connection). Returning true lets the event go on
  # as if the item was received (self switch, story switches set only when the gift succeeded...).
  def self.collect(key)
    @collected = true
    pos = @scripts.last
    @check_event = pos[0, 2] if pos
    $PokemonGlobal.ap_checked ||= []
    loc = @ap_ready ? @locations[key] : nil
    unless loc
      $PokemonGlobal.ap_checked |= [key]
      log("check #{key} recorded while the client is not connected")
      Kernel.pbMessage(_INTL("\\se[itemlevel]Found an Archipelago item!\\nIt will be sent when the Pokemon Reborn " \
                             "Client is connected."))
      return true
    end
    $PokemonGlobal.ap_checked |= [loc["id"]]
    send_msg("cmd" => "check", "locations" => [loc["id"]])
    log("check #{loc['id']} (#{key}): #{loc['item']} for #{loc['player']}")
    verb = BALL_KINDS.include?(loc["kind"]) ? "found" : "obtained"
    if loc["own"]
      @announced[loc["id"]] = true
      Kernel.pbMessage("\\se[itemlevel]#{$Trainer.name} #{verb} \\c[1]#{plain(item_label(loc['item'], loc['qty']))}\\c[0]!")
    else
      Kernel.pbMessage("\\se[itemlevel]#{$Trainer.name} #{verb} \\c[1]#{plain(loc['item'])}\\c[0] for " \
                       "\\c[1]#{plain(loc['player'])}\\c[0]!")
    end
    true
  end

  # A name from the multiworld in a message: not read as message codes or tags
  PLAIN = { "\\" => "\\\\", "&" => "&amp;", "<" => "&lt;", ">" => "&gt;" }.freeze
  def self.plain(text) = text.to_s.gsub(/[\\&<>]/, PLAIN)

  # Sends every AP location collected in this save: recorded ones (also while offline) and item balls taken before
  # the save was ever connected (vanilla item, self switch A on).
  def self.resync
    @resync_needed = false
    # offline checks were recorded by key: now that the locations are known, keep their id
    $PokemonGlobal.ap_checked = ($PokemonGlobal.ap_checked || []).map do |entry|
      entry.is_a?(String) && @locations[entry] ? @locations[entry]["id"] : entry
    end.uniq
    ids = $PokemonGlobal.ap_checked.grep(Integer)
    @locations.each do |key, loc|
      next unless BALL_KINDS.include?(loc["kind"])

      map_id, event_id = key.split(":").map(&:to_i)
      ids << loc["id"] if $game_self_switches[[map_id, event_id, "A"]]
    end
    ids.uniq!
    return if ids.empty?

    send_msg("cmd" => "check", "locations" => ids)
    log("resync: #{ids.length} locations")
  end

  # --- story gates (story_gates badge / both) ---

  # story_gates badge: the badge item opens the story at the leader's point
  def self.badge_gates? = $PokemonGlobal && $PokemonGlobal.ap_story_gates == "badge"

  # story_gates badge / both: a win without the badge is held back
  def self.held_gates? = $PokemonGlobal && HELD_GATES.include?($PokemonGlobal.ap_story_gates)

  def self.gym_stories = ($PokemonGlobal.ap_gym_story ||= {})

  def self.fights_won = ($PokemonGlobal.ap_fights_won ||= [])

  # A win without the badge item: the leader's `after` is held back until the badge arrives (story_due). Only
  # while the leader's own event runs (S586 Pulse App is also set in the Grand Hall; the map's interpreter keeps the ids
  # of the last event once it ended)
  def self.withhold?(kind, id, value)
    return false unless held_gates? && $Trainer

    interp = pbMapInterpreter
    n = interp && interp.running? && LEADER_EVENTS[event_of(interp)]
    return false if !n || $Trainer.badges[n] || !LEADERS[n].after.include?([kind, id, value])

    $PokemonGlobal.ap_withheld = withheld_leaders | [n]
    $game_map.need_refresh = true
    log("#{kind} #{id} = #{value} held back until the #{BADGE_NAMES[n]}")
    true
  end

  # badge indexes of the leaders beaten whose story effects wait for the badge
  def self.withheld_leaders
    $PokemonGlobal.ap_withheld || []
  end

  # A leader beaten without the badge: no rematch (the event shows its page after a win) and the gym door locked
  def self.waiting_for_badge?(n)
    n && $PokemonGlobal && withheld_leaders.include?(n) && !$Trainer.badges[n]
  end

  # A copy of a page without its conditions, to show it while the switch that shows it is held back
  def self.unconditional_page(pages, index)
    @unconditional_pages ||= {}
    @unconditional_pages[pages[index].object_id] ||= Marshal.load(Marshal.dump(pages[index])).tap do |page|
      c = page.condition
      c.switch1_valid = c.switch2_valid = c.variable_valid = c.self_switch_valid = false
    end
  end

  # Pages an event picks from instead of its own (nil: its own): the leader's page after a win while waiting for the
  # badge (no rematch), the fight pages while the story moved on without the fight, the triggers' first page, the door
  def self.leader_pages(map_id, event)
    pages = event.pages
    n = LEADER_EVENTS[[map_id, event.id]]
    return [unconditional_page(pages, LEADERS[n].win)] if waiting_for_badge?(n)
    return LEADERS[n].fight.map { |i| pages[i] } if keep_fight_page?(n)
    return pages[0, 1] if keep_fight_page?(LEADER_TRIGGERS[[map_id, event.id]])

    door_pages(LEADER_DOORS[[map_id, event.id]], pages)
  end

  # The gym door: locked while the leader waits for the badge (as after a vanilla win), open while the fight is kept
  def self.door_pages(n, pages)
    return nil unless n

    _, _, open, locked = LEADERS[n].door
    return [unconditional_page(pages, locked)] if waiting_for_badge?(n)

    keep_fight_page?(n) ? [unconditional_page(pages, open)] : nil
  end

  # Whether the badge opens leader n's story now (story_gates badge / both), nil if not:
  # - :held, a win without the badge, held back (withhold?), now that the badge is there;
  # - :point, story_gates badge: the badge, and the story reached the leader's point without the fight. Not before the
  #   point: an early S134 would turn earlier events to their late pages
  def self.story_due(n)
    leader = LEADERS[n]
    return nil if !held_gates? || !$Trainer || !$Trainer.badges[n] || $game_switches[leader.switch]
    return :held if withheld_leaders.include?(n)

    :point if badge_gates? && !fight_won?(n) && leader.point.call
  end

  # The badge opens the story where it is due (story_due). Shade's comes with the Railnet cutscene: railnet_trip
  def self.open_story_gates
    return unless held_gates? && can_give_items?

    LEADERS.each_key { |n| open_story(n) if n != RAILNET_LEADER && story_due(n) }
  end

  # Sets the leader's `after`; a gym with its own steps keeps its value (the fight stays available)
  def self.open_story(n)
    leader = LEADERS[n]
    held = story_due(n) == :held
    $PokemonGlobal.ap_withheld = withheld_leaders - [n]
    gym_stories[n] = $game_variables[leader.story_var[1]] if leader.gym && !held
    set_story(leader.after)
    log(held ? "story of leader #{n} released by the #{BADGE_NAMES[n]}" :
               "story gate of leader #{n} opened by the #{BADGE_NAMES[n]}, the fight stays available")
  end

  # [[:switch / :var, id, value]...]
  def self.set_story(values)
    values.each do |kind, id, value|
      if kind == :var
        $game_variables[id] = value
      else
        $game_switches[id] = value
      end
    end
    $game_map.need_refresh = true
  end

  # Shade's story (S139, story_due) plays the Railnet cutscene (RAILNET_SCENE): the player is free, on foot, off map 196
  def self.railnet_trip
    return unless story_due(RAILNET_LEADER) && can_give_items?
    return if $game_map.map_id == RAILNET_SCENE[0]
    return if $PokemonGlobal.surfing || $PokemonGlobal.diving || $PokemonGlobal.lavasurfing

    $PokemonGlobal.ap_railnet_return = [$game_map.map_id, $game_player.x, $game_player.y, $game_player.direction]
    open_story(RAILNET_LEADER)
    log("Railnet cutscene, back to #{$PokemonGlobal.ap_railnet_return.inspect} after it")
    transfer_player(RAILNET_SCENE[0], *RAILNET_SPOT, 8)
  end

  # Moves the player as Fly does (fade out, transfer, fade in)
  def self.transfer_player(map_id, x, y, direction)
    pbFadeOutIn(99999) do
      $game_temp.player_new_map_id = map_id
      $game_temp.player_new_x = x
      $game_temp.player_new_y = y
      $game_temp.player_new_direction = direction
      $scene.transfer_player
      $game_map.autoplay
      $game_map.refresh
    end
  end

  # Transfer Player of the Railnet cutscene played by the Omen Badge: back where the player was (the parameters of the
  # transfer to use instead, nil: the event's own)
  def self.railnet_return(map_id, event_id, parameters)
    back = $PokemonGlobal && $PokemonGlobal.ap_railnet_return
    return nil if !back || [map_id, event_id] != RAILNET_SCENE || parameters[0, 2] != [0, RAILNET_SHADE[0]]

    [0, *back, parameters[5]]
  end

  # that transfer started: what Shade's autorun sets is set, the message waits for the player to be back
  def self.railnet_returned
    set_story(RAILNET_SHADE[1])
    $PokemonGlobal.ap_railnet_return = nil
    $PokemonGlobal.ap_railnet_notice = true
    log("Railnet cutscene: back where the player was")
  end

  def self.railnet_notice
    return unless $PokemonGlobal && $PokemonGlobal.ap_railnet_notice && can_give_items?

    $PokemonGlobal.ap_railnet_notice = false
    Kernel.pbMessage(RAILNET_NOTICE)
  end

  def self.meet_cain
    return if $game_map.map_id != CAIN_ENTRANCE[0] || $game_variables[CAIN_STORY] != 3
    return unless CAIN_ENTRANCE[1].include?($game_player.x) && $game_player.y == CAIN_ENTRANCE[2]
    return unless can_give_items?

    $game_variables[CAIN_STORY] = 4
    $game_map.need_refresh = true
    log("Cain called at the entrance of Jasper Ward (E6 Story 4)")
  end

  # S283 came from the Millennium Badge: S456, which brings Elias, once the player is free in the salon (ELIAS_SALON)
  def self.call_elias
    return unless held_gates?
    return if $game_map.map_id != ELIAS_SALON[0] || $game_player.y.to_i < ELIAS_SALON[1]
    return if $game_switches[ELIAS_SWITCH] || !$game_switches[LEADERS[7].switch] || !LEADERS[7].point.call
    return unless can_give_items?

    $game_switches[ELIAS_SWITCH] = true
    $game_map.need_refresh = true
    log("Elias called in the castle salon (S#{ELIAS_SWITCH})")
  end

  def self.fight_won?(n) = fights_won.include?(n)

  # A leader's fight page: fight, badge line, then the gift IF whose success sets the story. A fight after the story
  # moved on sends its checks but its gift IF fails, so the story is not set back (Florinia would set E3 Story = 1
  # again). In a gym with its own steps the gift goes on: it moves the gym's value (gym_write?) and its steps play.
  def self.leader_script(n, script)
    if script.match?(BADGE_SCRIPT)
      # the gym's value at the win (none when the fight came before the story moved on: gym_active?)
      gym_stories[n] ||= gym_story(n) if gym_steps?(n)
      $PokemonGlobal.ap_fights_won = fights_won | [n]
      $game_map.need_refresh = true
      key = badge_key(script)
      return key ? collect(key) : yield
    end
    return yield unless script.include?("pbReceiveItem")

    late = $game_switches[LEADERS[n].switch] && !gym_steps?(n)
    result = yield
    late ? false : result
  end

  # story_gates badge: leader n stays on the fight pages until the fight is won, even once the story moved on
  def self.keep_fight_page?(n)
    return false if !n || !badge_gates?

    $game_switches.__ap_get_switch(LEADERS[n].switch) && !fight_won?(n)
  end

  # story_gates badge, a gym with its own story steps, once the story moved on without the fight: while one of its
  # events picks its page (Game_Event#refresh) or tests a condition (command_111), the leader's `after` reads as before
  # the win (switches off, the variable at the gym's own value). The same for FIGHT_VIEW while the fight is kept.
  def self.gym_view(map_id, event_id)
    outer = @gym_view
    outer_fight = @fight_view
    n = gym_of(map_id, event_id)
    left = GYM_LEAVE[[map_id, event_id]]
    @gym_view = gym_active?(n) && !(left && left.call) ? n : nil
    f = FIGHT_VIEW[[map_id, event_id]]
    @fight_view = keep_fight_page?(f) ? f : nil
    yield
  ensure
    @gym_view = outer
    @fight_view = outer_fight
  end

  # the gym's steps are not over: the story moved on without them (its switch set), their value is below the story's
  def self.gym_steps?(n)
    return false if !n || !LEADERS[n].gym || !badge_gates?
    return false unless $game_switches.__ap_get_switch(LEADERS[n].switch)

    gym_story(n) < LEADERS[n].story_var[2]
  end

  # The steps follow the gym's value until the fight is won, then while it is at least gym[2] (the leader and the
  # people around stay until the gift moves it). No value recorded at the win (the fight came before the story moved
  # on): the steps are over (Noel's default value would show his fight again)
  def self.gym_active?(n)
    return false unless gym_steps?(n)
    return true unless fight_won?(n)

    gym_stories.key?(n) && gym_story(n) >= LEADERS[n].gym[2]
  end

  def self.gym_of(map_id, event_id) = GYM_EVENTS[map_id] || GYM_EVENTS[[map_id, event_id]]

  # the value a switch / variable reads during gym_view (nil: its own)
  def self.gym_value(kind, id)
    return false if @fight_view && kind == :switch && id == LEADERS[@fight_view].switch
    return nil unless @gym_view
    return (kind == :var ? 0 : false) if (LEADERS[@gym_view].gym[3] || []).include?([kind, id])

    entry = LEADERS[@gym_view].after.find { |k, i, _| k == kind && i == id }
    return nil unless entry

    kind == :switch ? !entry[2] : gym_story(@gym_view)
  end

  def self.gym_story(n) = gym_stories[n] || LEADERS[n].gym[1]

  # Change Screen Color Tone (command_223): the castle doors' blackout fades in lit instead (not Radomus' own)
  def self.castle_lit?(map_id, event_id, tone)
    return false if !CASTLE_MAPS.include?(map_id) || [map_id, event_id] == LEADERS[7].event || !$PokemonGlobal
    return false unless [tone.red, tone.green, tone.blue, tone.gray].map(&:round) == CASTLE_DARK

    e11 = $game_variables.__ap_get_variable(159)
    return true if e11 >= CASTLE_REOPENED

    e11 == 0 && badge_gates? && !fight_won?(7)
  end

  # Show Text (command_101): the box said instead of the one starting with `line` (GYM_TEXTS), nil: the event's own
  def self.gym_text(map_id, event_id, line)
    n, texts = GYM_TEXTS[[map_id, event_id]]
    return nil if !n || !gym_active?(n)

    texts[line.to_s.rstrip]
  end

  # The badge arrives past the leader's point: the story moves on away from the player, the message says where
  def self.badge_notice(n)
    leader = LEADERS[n]
    return if !leader || !leader.notice || !badge_gates?
    return if $game_switches[leader.switch] || fight_won?(n) || !leader.point.call

    Kernel.pbMessage(leader.notice)
  end

  # A gym's event sets the story variable while its steps remain: it moves the gym's value, not the story (which would
  # go back). Only while the event runs: the map's interpreter keeps the ids of the last event once it ended.
  def self.gym_write?(id, value)
    interp = pbMapInterpreter
    return false unless interp && interp.running?

    n = gym_of(*event_of(interp))
    return false if !gym_steps?(n) || LEADERS[n].story_var[1] != id

    gym_stories[n] = value
    $game_map.need_refresh = true
    log("gym of leader #{n}: story #{value} (the story stays at #{$game_variables[id]})")
    true
  end

  # The map's interpreter starts an event: CHECK_TEXTS only follow a check of the same run
  def self.event_setup
    @check_event = nil
  end

  # --- items ---

  def self.can_give_items?
    return false if pbMapInterpreterRunning? || $game_temp.message_window_showing || $game_temp.menu_calling
    return false if $game_player.moving? || $game_switches[:In_Battle]

    true
  end

  def self.give_pending_items
    return if @pending_items.empty? || !can_give_items?

    index = $PokemonGlobal.ap_item_index || 0
    @pending_items.delete_if { |i, _| i < index }
    while (item = @pending_items.delete(index))
      give_item(item)
      index += 1
      $PokemonGlobal.ap_item_index = index
    end
  end

  # "Oran Berry x3" when an AP item gives several copies (quantity of items.json), else the name alone
  def self.item_label(name, qty)
    qty.to_i > 1 ? "#{name} x#{qty.to_i}" : name
  end

  def self.give_item(item)
    if item["symbol"].to_s =~ /\ABADGE(\d+)\z/
      give_badge($1.to_i, item)
      return
    end
    symbol = item["symbol"] && item["symbol"].to_sym
    return give_crystal(item) if symbol == CRYSTAL_KEY

    unless symbol && $cache.items[symbol]
      log("unknown item #{item.inspect}")
      return
    end
    qty = [item["qty"].to_i, 1].max
    stored = $PokemonBag.pbStoreItem(symbol, qty)
    log("item #{item['index']}: #{symbol} x#{qty} from #{item['from']} (stored: #{stored})")
    label = item_label(item["name"], qty)
    if !stored
      Kernel.pbMessage("Received \\c[1]#{plain(label)}\\c[0] from #{plain(item['from'])}, but you already have 999...")
    else
      announce(item, label)
      # also for our own Exp. All found on a check (not announced: the check already said what was found)
      ask_exp_all if symbol == EXP_ALL[0]
    end
  end

  # "Received X from Y!", unless the check that held our own item showed it in this session (@announced)
  def self.announce(item, label, article = "")
    return if @announced.delete(item["own_location"])

    Kernel.pbMessage("\\se[itemlevel]Received #{article}\\c[1]#{plain(label)}\\c[0] from \\c[1]#{plain(item['from'])}\\c[0]!")
  end

  # The question of the Spinel Town event, now that the player has the Exp. All (EXP_ALL)
  def self.ask_exp_all
    off, on, switch = EXP_ALL
    return unless Kernel.pbConfirmMessage(_INTL("Would you like to turn the EXP All on now?"))

    $game_switches[switch] = true
    $PokemonBag.pbChangeItem(off, on)
    log("Exp. All turned on")
  end

  # highest crystal in the bag (0: none)
  def self.crystal_level
    (CRYSTALS.rindex { |c| $PokemonBag.pbQuantity(c) > 0 } || -1) + 1
  end

  # The game's events take the crystal they replace (Iolia Valley map 335 ev157 / 158, map 343 ev3): with the AP
  # Crystal Key the mod does it, those gives are AP checks
  def self.keep_crystal?(item)
    return false unless CRYSTALS.include?(item)

    log("#{item} not taken: the Crystal Key gives the crystals")
    true
  end

  def self.give_crystal(item)
    level = crystal_level
    return log("item #{item['index']}: Crystal Key from #{item['from']}, all crystals owned") if level >= CRYSTALS.length

    $PokemonBag.__ap_pbDeleteItem(CRYSTALS[level - 1]) if level > 0
    stored = $PokemonBag.__ap_pbStoreItem(CRYSTALS[level], 1)
    log("item #{item['index']}: #{CRYSTALS[level]} from #{item['from']} (stored: #{stored})")
    announce(item, getItemName(CRYSTALS[level]))
  end

  def self.give_badge(n, item)
    $Trainer.badges[n] = true
    log("item #{item['index']}: badge #{n} from #{item['from']}")
    announce(item, item["name"], "the ")
    # also for our own badge found on a check (not announced: the check said what was found, not where the story went)
    badge_notice(n)
    open_story_gates
  end
end

# Hooks. Each alias wraps whatever the method is at load time (the randomizer's versions included).
class Interpreter
  alias_method :__ap_pbExecuteScript, :pbExecuteScript unless method_defined?(:__ap_pbExecuteScript)

  def pbExecuteScript(script)
    RebornAP.run_script(self, script) { __ap_pbExecuteScript(script) }
  end

  alias_method :__ap_command_102, :command_102 unless method_defined?(:__ap_command_102)

  # Show Choices: Ame's password question is answered "No" once the yaml passwords are set; the question after a check's
  # skipped texts (RebornAP.skip_choice?) too, without showing it
  def command_102
    if RebornAP.skip_choice?(@map_id, @event_id, @list[@index].parameters[0])
      @branch[@list[@index].indent] = 1
      return true
    end
    return __ap_command_102 unless RebornAP.ame_question?(self, @list[@index])

    RebornAP.wait_for_passwords
    RebornAP.apply_passwords(true)
    @branch[@list[@index].indent] = 1
    true
  end

  alias_method :__ap_setup, :setup unless method_defined?(:__ap_setup)
  alias_method :__ap_command_201, :command_201 unless method_defined?(:__ap_command_201)

  # only the map's interpreter: parallel events and common events start their own while the event runs
  def setup(list, event_id, map_id = nil)
    __ap_setup(list, event_id, map_id)
    RebornAP.event_setup if equal?(pbMapInterpreter)
  end

  # Transfer Player: the end of the Railnet cutscene played by the Omen Badge goes back where the player was
  # (RebornAP.railnet_return), once the engine started the transfer (@index moved on; a message still showing makes
  # the engine run this command again). @event_id 0: on a map connected to 196 the engine would unlock its event 26
  def command_201
    back = RebornAP.railnet_return(@map_id, @event_id, @parameters)
    return __ap_command_201 unless back

    index = @index
    params = @parameters
    @parameters = back
    result = __ap_command_201
    if @index != index
      RebornAP.railnet_returned
      @event_id = 0
    end
    result
  ensure
    @parameters = params if params
  end

  alias_method :__ap_command_223, :command_223 unless method_defined?(:__ap_command_223)

  # Change Screen Color Tone: Vanhanen Castle's blackout fades in lit when it no longer belongs (RebornAP.castle_lit?)
  def command_223
    return __ap_command_223 unless RebornAP.castle_lit?(@map_id, @event_id, @parameters[0])

    $game_screen.start_tone_change(Tone.new(0, 0, 0, 0), @parameters[1] * 2)
    true
  end

  alias_method :__ap_command_101, :command_101 unless method_defined?(:__ap_command_101)
  alias_method :__ap_command_111, :command_111 unless method_defined?(:__ap_command_111)

  # Show Text: a box replaced (RebornAP.gym_text). Reborn's command_101 shows the box itself and joins its continuation
  # lines (401), so it runs on a copy of the list with the new text and empty continuation lines (setting
  # $game_temp.message_text as RMXP does waits forever: no message window shows it)
  def command_101
    # CHECK_TEXTS: the interpreter skips the continuation lines, a following Show Choices goes through command_102
    return true if RebornAP.skip_text?(@map_id, @event_id, @list[@index].parameters[0])

    text = RebornAP.gym_text(@map_id, @event_id, @list[@index].parameters[0])
    return __ap_command_101 unless text

    list = @list
    @list = list.dup
    @list[@index] = list[@index].dup.tap { |c| c.parameters = [text] }
    i = @index + 1
    while list[i] && list[i].code == 401
      @list[i] = list[i].dup.tap { |c| c.parameters = [""] }
      i += 1
    end
    __ap_command_101
  ensure
    @list = list if list
  end

  # Conditional Branch on a switch / variable: through gym_view, as the pages (not on a script: its fight would run
  # in it)
  def command_111
    return __ap_command_111 unless [0, 1].include?(@parameters[0])

    RebornAP.gym_view(@map_id, @event_id) { __ap_command_111 }
  end
end

class Game_Switches
  alias_method :__ap_set_switch, :[]= unless method_defined?(:__ap_set_switch)
  alias_method :__ap_get_switch, :[] unless method_defined?(:__ap_get_switch)

  def [](switch_id)
    value = RebornAP.gym_value(:switch, switch_id)
    value.nil? ? __ap_get_switch(switch_id) : value
  end

  def []=(switch_id, value)
    id = switch_id.is_a?(Symbol) ? Switches[switch_id] : switch_id
    return if RebornAP.withhold?(:switch, id, value)

    __ap_set_switch(switch_id, value)
  end
end

class Game_Variables
  alias_method :__ap_set_variable, :[]= unless method_defined?(:__ap_set_variable)
  alias_method :__ap_get_variable, :[] unless method_defined?(:__ap_get_variable)

  def [](variable_id)
    value = RebornAP.gym_value(:var, variable_id)
    value.nil? ? __ap_get_variable(variable_id) : value
  end

  def []=(variable_id, value)
    id = variable_id.is_a?(Symbol) ? Variables[variable_id] : variable_id
    return if RebornAP.withhold?(:var, id, value) || RebornAP.gym_write?(id, value)

    __ap_set_variable(variable_id, value)
  end
end

class Game_Event
  alias_method :__ap_refresh, :refresh unless method_defined?(:__ap_refresh)
  alias_method :__ap_initialize, :initialize unless method_defined?(:__ap_initialize)

  # created when the map loads
  def initialize(*args)
    __ap_initialize(*args)
    RebornAP.event_placed(self, @map_id)
  end

  # refresh picks the last page whose conditions hold: among RebornAP.leader_pages when set, through gym_view
  def refresh
    shown = RebornAP.leader_pages(@map_id, @event)
    return RebornAP.gym_view(@map_id, @event.id) { __ap_refresh } unless shown

    pages = @event.pages
    @event.pages = shown
    RebornAP.gym_view(@map_id, @event.id) { __ap_refresh }
  ensure
    @event.pages = pages if pages
  end
end

# Add Password in the PC: passwords come from the yaml only
class PasswordPC
  def shouldShow?
    false
  end
end

class PokemonBag
  alias_method :__ap_pbStoreItem, :pbStoreItem unless method_defined?(:__ap_pbStoreItem)
  alias_method :__ap_pbDeleteItem, :pbDeleteItem unless method_defined?(:__ap_pbDeleteItem)

  def pbStoreItem(item, qty = 1)
    RebornAP.give(item) { __ap_pbStoreItem(item, qty) }
  end

  def pbDeleteItem(item, qty = 1)
    return true if RebornAP.keep_crystal?(item)

    __ap_pbDeleteItem(item, qty)
  end
end

unless Kernel.respond_to?(:__ap_itemBall)
  Kernel.singleton_class.send(:alias_method, :__ap_itemBall, :pbItemBall)
  Kernel.singleton_class.send(:alias_method, :__ap_receiveItem, :pbReceiveItem)
end
def Kernel.pbItemBall(item, quantity = 1, plural = nil)
  RebornAP.give(item) { __ap_itemBall(item, quantity, plural) }
end

def Kernel.pbReceiveItem(item, quantity = 1, plural = nil)
  RebornAP.give(item) { __ap_receiveItem(item, quantity, plural) }
end

Events.onMapUpdate += proc { |sender, e|
  RebornAP.update
}
