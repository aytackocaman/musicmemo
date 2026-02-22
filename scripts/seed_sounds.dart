// ignore_for_file: avoid_print
/// Script to generate placeholder WAV sounds and upload to Supabase Storage.
/// Run: dart run scripts/seed_sounds.dart
///
/// Generates 25 unique tones per category using different frequencies,
/// uploads to Supabase Storage, and inserts metadata into the sounds table.

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

// -- Configuration --
// Read from .env or hardcode for script use
const supabaseUrl = String.fromEnvironment('SUPABASE_URL',
    defaultValue: ''); // Set via --define or edit here
const supabaseKey = String.fromEnvironment('SUPABASE_KEY',
    defaultValue: ''); // Set via --define or edit here

/// Sound name templates per category
const Map<String, List<String>> categoryNames = {
  'farm_animals': ['Cow Moo', 'Pig Oink', 'Chicken Cluck', 'Horse Neigh', 'Sheep Baa', 'Donkey Bray', 'Rooster Crow', 'Duck Quack', 'Goat Bleat', 'Turkey Gobble', 'Dog Bark', 'Cat Meow', 'Goose Honk', 'Rabbit Thump', 'Bull Snort', 'Lamb Cry', 'Hen Cackle', 'Pony Whinny', 'Piglet Squeal', 'Calf Call', 'Ox Bellow', 'Mare Nicker', 'Chick Peep', 'Ram Grunt', 'Sow Grunt'],
  'wild_animals': ['Lion Roar', 'Wolf Howl', 'Elephant Trumpet', 'Monkey Screech', 'Bear Growl', 'Tiger Snarl', 'Hyena Laugh', 'Gorilla Chest Beat', 'Hippo Grunt', 'Rhino Snort', 'Zebra Bark', 'Giraffe Hum', 'Cheetah Chirp', 'Leopard Purr', 'Fox Yip', 'Deer Bellow', 'Moose Call', 'Coyote Howl', 'Panther Scream', 'Jaguar Growl', 'Bison Grunt', 'Antelope Snort', 'Boar Squeal', 'Badger Hiss', 'Raccoon Chitter'],
  'birds': ['Eagle Screech', 'Owl Hoot', 'Parrot Squawk', 'Robin Song', 'Crow Caw', 'Dove Coo', 'Hawk Cry', 'Seagull Call', 'Woodpecker Drum', 'Canary Trill', 'Sparrow Chirp', 'Finch Song', 'Blue Jay Call', 'Cardinal Whistle', 'Hummingbird Buzz', 'Pelican Call', 'Swan Song', 'Penguin Call', 'Flamingo Honk', 'Toucan Call', 'Peacock Cry', 'Vulture Hiss', 'Kookaburra Laugh', 'Loon Wail', 'Nightingale Song'],
  'ocean_creatures': ['Whale Song', 'Dolphin Click', 'Seal Bark', 'Shrimp Snap', 'Walrus Bellow', 'Sea Lion Roar', 'Fish Splash', 'Crab Click', 'Orca Call', 'Narwhal Buzz', 'Manatee Squeak', 'Otter Chirp', 'Penguin Honk', 'Pufferfish Pop', 'Jellyfish Pulse', 'Starfish Crackle', 'Lobster Click', 'Turtle Grunt', 'Seahorse Click', 'Stingray Swoosh', 'Clam Snap', 'Coral Crackle', 'Anemone Pop', 'Squid Jet', 'Octopus Squish'],
  'insects': ['Bee Buzz', 'Cricket Chirp', 'Mosquito Whine', 'Fly Buzz', 'Cicada Song', 'Grasshopper Chirp', 'Beetle Click', 'Ant March', 'Dragonfly Hum', 'Butterfly Flutter', 'Wasp Buzz', 'Moth Flutter', 'Ladybug Click', 'Firefly Flash', 'Caterpillar Munch', 'Centipede Scuttle', 'Spider Spin', 'Flea Jump', 'Tick Click', 'Cockroach Scurry', 'Termite Chew', 'Praying Mantis Snap', 'Locust Swarm', 'Hornet Dive', 'Earwig Pinch'],
  'piano': ['C3 Note', 'D3 Note', 'E3 Note', 'F3 Note', 'G3 Note', 'A3 Note', 'B3 Note', 'C4 Note', 'D4 Note', 'E4 Note', 'F4 Note', 'G4 Note', 'A4 Note', 'B4 Note', 'C5 Note', 'D5 Note', 'E5 Note', 'F5 Note', 'G5 Note', 'A5 Note', 'B5 Note', 'C Major Chord', 'F Major Chord', 'G Major Chord', 'A Minor Chord'],
  'guitar': ['Open E String', 'Open A String', 'Open D String', 'Open G String', 'Open B String', 'High E String', 'C Chord Strum', 'G Chord Strum', 'D Chord Strum', 'Am Chord Strum', 'Em Chord Strum', 'F Chord Strum', 'Power Chord E', 'Power Chord A', 'Slide Up', 'Slide Down', 'Hammer On', 'Pull Off', 'Palm Mute', 'Harmonic 12', 'Bend Note', 'Vibrato', 'Pick Scratch', 'Tap Note', 'Wah Wah'],
  'drums': ['Kick Drum', 'Snare Hit', 'Hi-Hat Closed', 'Hi-Hat Open', 'Crash Cymbal', 'Ride Cymbal', 'Tom High', 'Tom Mid', 'Tom Low', 'Floor Tom', 'Rimshot', 'Cross Stick', 'Cowbell', 'Tambourine', 'Clap', 'Shaker', 'Bongo High', 'Bongo Low', 'Conga Slap', 'Conga Open', 'Woodblock', 'Triangle', 'Cabasa', 'Guiro', 'Timbale'],
  'electronic': ['808 Kick', '808 Snare', '808 Hi-Hat', 'Sub Bass', 'Synth Lead', 'Acid Squelch', 'Arp Pattern', 'Pad Swell', 'Noise Sweep', 'Glitch Hit', 'Wobble Bass', 'Reese Bass', 'Pluck Synth', 'Chip Tune', 'Bit Crush', 'Filter Rise', 'Filter Drop', 'Laser Zap', 'Robot Voice', 'Dial Up', 'Static Burst', 'Digital Bell', 'FM Brass', 'Saw Wave', 'Square Wave'],
  'orchestra': ['Violin Pizz', 'Viola Sustain', 'Cello Note', 'Bass Bow', 'Flute Trill', 'Oboe Note', 'Clarinet Run', 'Bassoon Low', 'French Horn', 'Trumpet Call', 'Trombone Slide', 'Tuba Note', 'Harp Gliss', 'Timpani Roll', 'Snare Roll', 'Cymbal Crash', 'Glockenspiel', 'Xylophone', 'Celesta', 'Piano Chord', 'String Section', 'Brass Section', 'Woodwind Choir', 'Full Tutti', 'Pizzicato Section'],
  'weather': ['Thunder Clap', 'Light Rain', 'Heavy Rain', 'Hail Storm', 'Wind Gust', 'Tornado Roar', 'Snow Crunch', 'Ice Crack', 'Lightning Strike', 'Drizzle', 'Storm Surge', 'Blizzard Wind', 'Fog Horn', 'Rainbow Chime', 'Sunshine Warm', 'Cloud Roll', 'Frost Crack', 'Dewdrop', 'Sleet Patter', 'Hurricane Wind', 'Monsoon Rain', 'Dust Storm', 'Heat Wave', 'Cold Snap', 'Breeze Rustle'],
  'water': ['Ocean Wave', 'River Flow', 'Waterfall', 'Rain Drop', 'Bubble Pop', 'Stream Gurgle', 'Splash', 'Drip', 'Underwater', 'Fountain', 'Ice Melt', 'Puddle Step', 'Lake Lap', 'Geyser Burst', 'Tap Drip', 'Shower Spray', 'Sprinkler', 'Hose Spray', 'Pool Dive', 'Hot Spring', 'Glacier Crack', 'Dam Flow', 'Canal Flow', 'Marsh Bubble', 'Swamp Gurgle'],
  'forest': ['Leaves Rustle', 'Branch Snap', 'Owl Night', 'Wolf Distant', 'Creek Babble', 'Wind Trees', 'Bird Dawn', 'Frog Chorus', 'Deer Walk', 'Squirrel Chatter', 'Pine Creak', 'Acorn Fall', 'Mushroom Pop', 'Moss Squish', 'Bark Crack', 'Root Snap', 'Fallen Log', 'Forest Rain', 'Canopy Drip', 'Trail Crunch', 'Campfire Crack', 'Tent Zip', 'Lantern Creak', 'Axe Chop', 'Saw Cut'],
  'wind': ['Gentle Breeze', 'Strong Gust', 'Howling Wind', 'Whistling Wind', 'Wind Chime', 'Flag Flap', 'Sail Billow', 'Dust Devil', 'Leaf Tornado', 'Wind Tunnel', 'Rooftop Wind', 'Canyon Echo', 'Prairie Wind', 'Mountain Gale', 'Desert Wind', 'Arctic Blast', 'Tropical Breeze', 'Tornado Siren', 'Wind Farm', 'Turbine Spin', 'Balloon Pop', 'Kite Flutter', 'Windmill Turn', 'Sail Snap', 'Draft Whistle'],
  'fire': ['Campfire Crackle', 'Match Strike', 'Lighter Click', 'Bonfire Roar', 'Candle Flicker', 'Fireplace Pop', 'Torch Whoosh', 'Ember Glow', 'Log Split', 'Paper Burn', 'Charcoal Sizzle', 'Flame Burst', 'Fire Alarm', 'Smoke Alarm', 'Sparkler Fizz', 'Firework Pop', 'Firework Boom', 'Fuse Burn', 'Welding Arc', 'Forge Hammer', 'Kiln Crackle', 'Lava Flow', 'Volcano Rumble', 'Gas Burner', 'Fire Extinguisher'],
  'kitchen': ['Pot Boil', 'Pan Sizzle', 'Knife Chop', 'Blender Whir', 'Microwave Beep', 'Oven Timer', 'Fridge Hum', 'Water Pour', 'Glass Clink', 'Plate Stack', 'Fork Scrape', 'Cork Pop', 'Can Open', 'Egg Crack', 'Toast Pop', 'Kettle Whistle', 'Mixer Spin', 'Ice Crush', 'Dish Wash', 'Cabinet Close', 'Drawer Slide', 'Spoon Stir', 'Whisk Beat', 'Mortar Pound', 'Timer Ding'],
  'office': ['Keyboard Type', 'Mouse Click', 'Printer Run', 'Paper Shuffle', 'Stapler Click', 'Pen Click', 'Chair Roll', 'Door Open', 'Phone Ring', 'Copy Machine', 'Shredder Run', 'Tape Pull', 'Stamp Press', 'Binder Clip', 'File Drawer', 'Coffee Pour', 'Water Cooler', 'AC Hum', 'Elevator Ding', 'Intercom Buzz', 'Clock Tick', 'Marker Squeak', 'Paper Tear', 'Hole Punch', 'Letter Open'],
  'doorbell': ['Classic Ding', 'Double Ding', 'Buzzer', 'Chime', 'Musical Bell', 'Intercom Ring', 'Alarm Beep', 'Clock Alarm', 'Timer Buzz', 'Car Alarm', 'Fire Alarm', 'Smoke Detector', 'Wake Up Alarm', 'Phone Alarm', 'School Bell', 'Church Bell', 'Ship Bell', 'Bicycle Bell', 'Boxing Bell', 'Dinner Bell', 'Cow Bell', 'Jingle Bell', 'Temple Bell', 'Wind Bell', 'Door Knock'],
  'tools': ['Hammer Hit', 'Saw Cut', 'Drill Spin', 'Wrench Turn', 'Screwdriver Turn', 'Sandpaper Rub', 'Nail Gun', 'Staple Gun', 'Clamp Close', 'Vice Grip', 'Level Click', 'Tape Measure', 'Chisel Strike', 'File Scrape', 'Pliers Squeeze', 'Bolt Tighten', 'Rivet Pop', 'Weld Spark', 'Grinder Spin', 'Paint Spray', 'Brush Stroke', 'Roller Roll', 'Ladder Unfold', 'Wheelbarrow', 'Cement Mix'],
  'phone': ['Text Message', 'Call Ring', 'Notification Ping', 'Email Alert', 'Camera Shutter', 'Lock Click', 'Unlock Slide', 'App Open', 'Keyboard Tap', 'Voice Memo', 'Alarm Tone', 'Timer End', 'Screenshot', 'Power Off', 'Charging Beep', 'Low Battery', 'Airplane Mode', 'Silent Mode', 'Vibrate Buzz', 'Siri Ding', 'FaceTime Ring', 'Airdrop Whoosh', 'Payment Ding', 'Compass Click', 'Map Pin'],
  'cars': ['Engine Start', 'Engine Rev', 'Horn Honk', 'Tire Screech', 'Door Close', 'Window Down', 'Windshield Wiper', 'Turn Signal', 'Gear Shift', 'Parking Brake', 'Trunk Close', 'Key Turn', 'Seatbelt Click', 'AC Blast', 'Radio Tune', 'Exhaust Pop', 'Turbo Whistle', 'Brake Squeal', 'Suspension Bounce', 'Gravel Drive', 'Puddle Splash', 'Gas Pump', 'Car Wash', 'Ice Scraper', 'Alarm Chirp'],
  'trains': ['Steam Whistle', 'Diesel Horn', 'Rail Click', 'Station Bell', 'Door Chime', 'Brake Hiss', 'Coupling Clank', 'Tunnel Echo', 'Crossing Bell', 'Ticket Punch', 'Platform Announce', 'Engine Chug', 'Coal Shovel', 'Water Fill', 'Signal Change', 'Switch Track', 'Overhead Wire', 'Express Pass', 'Slow Approach', 'Station Stop', 'Departure Whistle', 'Night Train', 'Freight Rumble', 'Caboose Rattle', 'Handcar Pump'],
  'planes': ['Jet Takeoff', 'Propeller Spin', 'Cabin Ding', 'Landing Gear', 'Turbulence Bump', 'Cockpit Radio', 'Safety Demo', 'Overhead Bin', 'Tray Table', 'Window Shade', 'Engine Roar', 'Wind Rush', 'Altitude Beep', 'Autopilot Click', 'Flap Extend', 'Reverse Thrust', 'Tire Touch', 'Brake Apply', 'Taxiway Turn', 'Gate Arrival', 'Jetway Connect', 'Cargo Load', 'Fuel Pump', 'De-Ice Spray', 'Helicopter Chop'],
  'boats': ['Foghorn', 'Anchor Drop', 'Sail Flap', 'Wave Crash', 'Engine Putt', 'Bell Ring', 'Rope Creak', 'Hull Slap', 'Winch Turn', 'Dock Bump', 'Seagull Cry', 'Buoy Bell', 'Compass Click', 'Map Unfold', 'Porthole Open', 'Cabin Door', 'Galley Cook', 'Fishing Reel', 'Net Splash', 'Whale Nearby', 'Storm Warning', 'Radio Static', 'Horn Signal', 'Submarine Dive', 'Periscope Rise'],
  'bikes': ['Engine Kick', 'Throttle Rev', 'Gear Click', 'Chain Rattle', 'Exhaust Rumble', 'Horn Beep', 'Brake Squeak', 'Tire Spin', 'Kickstand Drop', 'Helmet Click', 'Visor Flip', 'Glove Snap', 'Key Turn', 'Fuel Cap', 'Mirror Adjust', 'Clutch Pull', 'Speedometer Tick', 'Wind Ride', 'Gravel Slide', 'Wheelie Land', 'Burnout Smoke', 'Lane Split', 'Tunnel Echo', 'Rain Ride', 'Night Cruise'],
  'ball_sports': ['Soccer Kick', 'Basketball Bounce', 'Tennis Racket', 'Baseball Bat', 'Golf Swing', 'Bowling Strike', 'Volleyball Spike', 'Cricket Bat', 'Rugby Tackle', 'Billiard Break', 'Table Tennis', 'Badminton Smash', 'Handball Throw', 'Dodgeball Hit', 'Water Polo Splash', 'Lacrosse Catch', 'Field Hockey', 'Polo Mallet', 'Squash Wall', 'Racquetball', 'Referee Whistle', 'Crowd Cheer', 'Scoreboard Buzz', 'Net Swish', 'Goal Horn'],
  'combat': ['Boxing Punch', 'Karate Chop', 'Sword Clash', 'Shield Block', 'Arrow Release', 'Whip Crack', 'Staff Strike', 'Wrestling Slam', 'Judo Throw', 'Fencing Lunge', 'Nunchaku Spin', 'Kick Impact', 'Bell Round', 'Crowd Roar', 'Glove Touch', 'Mouth Guard', 'Corner Stool', 'Tape Wrap', 'Jump Rope', 'Heavy Bag', 'Speed Bag', 'Skip Step', 'Exhale Strike', 'Kiai Shout', 'Bow Respect'],
  'water_sports': ['Dive Splash', 'Swim Stroke', 'Surfboard Wax', 'Wave Ride', 'Kayak Paddle', 'Canoe Dip', 'Jet Ski Rev', 'Water Ski', 'Wake Board', 'Parasail Lift', 'Snorkel Breath', 'Scuba Bubble', 'Raft Inflate', 'Pool Flip Turn', 'Starting Block', 'Lane Line', 'Goggles Snap', 'Cap Stretch', 'Towel Snap', 'Whistle Blow', 'Medal Clink', 'Trophy Lift', 'Photo Flash', 'Victory Lap', 'Podium Step'],
  'winter_sports': ['Ski Swoosh', 'Snowboard Carve', 'Ice Skate', 'Hockey Puck', 'Sled Whoosh', 'Curling Stone', 'Ski Pole Plant', 'Binding Click', 'Boot Crunch', 'Chairlift Hum', 'Gondola Sway', 'Mogul Bump', 'Jump Launch', 'Landing Pack', 'Edge Scrape', 'Wax Apply', 'Goggles Wipe', 'Glove Clap', 'Avalanche Rumble', 'Snow Machine', 'Ice Resurface', 'Horn Start', 'Finish Bell', 'Clock Stop', 'Medal Award'],
  'arcade': ['Coin Insert', 'Button Mash', 'Joystick Click', 'Power Up', 'Level Up', 'Game Over', 'High Score', 'Extra Life', 'Boss Fight', 'Treasure Open', 'Key Collect', 'Door Unlock', 'Teleport Zap', 'Health Pack', 'Shield Up', 'Sword Swing', 'Magic Spell', 'Explosion Boom', 'Laser Blast', 'Jump Boing', 'Slide Whoosh', 'Dash Zoom', 'Victory Fanfare', 'Bonus Round', 'Continue Countdown'],
};

/// Musical note frequencies for generating tones
const List<double> noteFrequencies = [
  130.81, 138.59, 146.83, 155.56, 164.81, 174.61, 185.00, // C3 to F#3
  196.00, 207.65, 220.00, 233.08, 246.94, 261.63, 277.18, // G3 to C#4
  293.66, 311.13, 329.63, 349.23, 369.99, 392.00, 415.30, // D4 to G#4
  440.00, 466.16, 493.88, 523.25, // A4 to C5
];

/// Waveform types for variety between categories
enum WaveType { sine, triangle, square, sawtooth }

/// Generate a WAV file as bytes
Uint8List generateWav({
  required double frequency,
  required WaveType waveType,
  int sampleRate = 22050,
  double durationSec = 2.0,
  double amplitude = 0.7,
}) {
  final numSamples = (sampleRate * durationSec).toInt();
  final dataSize = numSamples * 2; // 16-bit mono
  final fileSize = 44 + dataSize;

  final buffer = ByteData(fileSize);

  // RIFF header
  buffer.setUint8(0, 0x52); // R
  buffer.setUint8(1, 0x49); // I
  buffer.setUint8(2, 0x46); // F
  buffer.setUint8(3, 0x46); // F
  buffer.setUint32(4, fileSize - 8, Endian.little);
  buffer.setUint8(8, 0x57); // W
  buffer.setUint8(9, 0x41); // A
  buffer.setUint8(10, 0x56); // V
  buffer.setUint8(11, 0x45); // E

  // fmt chunk
  buffer.setUint8(12, 0x66); // f
  buffer.setUint8(13, 0x6D); // m
  buffer.setUint8(14, 0x74); // t
  buffer.setUint8(15, 0x20); // (space)
  buffer.setUint32(16, 16, Endian.little); // chunk size
  buffer.setUint16(20, 1, Endian.little); // PCM
  buffer.setUint16(22, 1, Endian.little); // mono
  buffer.setUint32(24, sampleRate, Endian.little);
  buffer.setUint32(28, sampleRate * 2, Endian.little); // byte rate
  buffer.setUint16(32, 2, Endian.little); // block align
  buffer.setUint16(34, 16, Endian.little); // bits per sample

  // data chunk
  buffer.setUint8(36, 0x64); // d
  buffer.setUint8(37, 0x61); // a
  buffer.setUint8(38, 0x74); // t
  buffer.setUint8(39, 0x61); // a
  buffer.setUint32(40, dataSize, Endian.little);

  // Generate samples
  for (int i = 0; i < numSamples; i++) {
    final t = i / sampleRate;
    double sample;

    switch (waveType) {
      case WaveType.sine:
        sample = sin(2 * pi * frequency * t);
        break;
      case WaveType.triangle:
        final p = (t * frequency) % 1.0;
        sample = 4 * (p < 0.5 ? p : 1 - p) - 1;
        break;
      case WaveType.square:
        sample = sin(2 * pi * frequency * t) >= 0 ? 1.0 : -1.0;
        sample *= 0.5; // softer
        break;
      case WaveType.sawtooth:
        sample = 2 * ((t * frequency) % 1.0) - 1;
        sample *= 0.6; // softer
        break;
    }

    // Fade in/out (first and last 10%)
    final fadeLength = numSamples * 0.1;
    double envelope = 1.0;
    if (i < fadeLength) {
      envelope = i / fadeLength;
    } else if (i > numSamples - fadeLength) {
      envelope = (numSamples - i) / fadeLength;
    }

    final value = (sample * amplitude * envelope * 32767).toInt().clamp(-32768, 32767);
    buffer.setInt16(44 + i * 2, value, Endian.little);
  }

  return buffer.buffer.asUint8List();
}

Future<void> main() async {
  // Check configuration
  String url = supabaseUrl;
  String key = supabaseKey;

  if (url.isEmpty || key.isEmpty) {
    // Try reading from .env file
    try {
      final envFile = await _readEnvFile();
      url = envFile['SUPABASE_URL'] ?? '';
      key = envFile['SUPABASE_KEY'] ?? '';
    } catch (_) {}
  }

  if (url.isEmpty || key.isEmpty) {
    print('Error: Set SUPABASE_URL and SUPABASE_KEY');
    print('Either via --define or in .env file');
    return;
  }

  print('Supabase URL: $url');
  print('Generating and uploading sounds...\n');

  // Create storage bucket if it doesn't exist
  try {
    await http.post(
      Uri.parse('$url/storage/v1/bucket'),
      headers: {
        'Authorization': 'Bearer $key',
        'apikey': key,
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'id': 'sounds',
        'name': 'sounds',
        'public': true,
      }),
    );
    print('Created storage bucket "sounds"');
  } catch (e) {
    print('Bucket may already exist: $e');
  }

  // Assign waveform types to categories for variety
  final waveTypes = WaveType.values;
  int categoryIndex = 0;

  for (final entry in categoryNames.entries) {
    final categoryId = entry.key;
    final names = entry.value;
    final waveType = waveTypes[categoryIndex % waveTypes.length];

    print('[$categoryId] Generating ${names.length} sounds (${waveType.name} wave)...');

    final soundRows = <Map<String, dynamic>>[];

    for (int i = 0; i < names.length && i < 25; i++) {
      final name = names[i];
      final frequency = noteFrequencies[i % noteFrequencies.length];
      // Add slight variation per category so same index sounds different
      final adjustedFreq = frequency * (1.0 + categoryIndex * 0.02);

      final wavBytes = generateWav(
        frequency: adjustedFreq,
        waveType: waveType,
        durationSec: 2.0,
      );

      final fileName = '${name.toLowerCase().replaceAll(' ', '_').replaceAll(RegExp(r'[^a-z0-9_]'), '')}.wav';
      final filePath = '$categoryId/$fileName';

      // Upload to Supabase Storage
      final uploadRes = await http.post(
        Uri.parse('$url/storage/v1/object/sounds/$filePath'),
        headers: {
          'Authorization': 'Bearer $key',
          'apikey': key,
          'Content-Type': 'audio/wav',
          'x-upsert': 'true',
        },
        body: wavBytes,
      );

      if (uploadRes.statusCode == 200 || uploadRes.statusCode == 201) {
        soundRows.add({
          'category_id': categoryId,
          'name': name,
          'file_path': filePath,
          'duration_ms': 2000,
          'file_size_bytes': wavBytes.length,
        });
      } else {
        print('  Failed to upload $filePath: ${uploadRes.statusCode} ${uploadRes.body}');
      }
    }

    // Insert sound metadata into DB
    if (soundRows.isNotEmpty) {
      final insertRes = await http.post(
        Uri.parse('$url/rest/v1/sounds'),
        headers: {
          'Authorization': 'Bearer $key',
          'apikey': key,
          'Content-Type': 'application/json',
          'Prefer': 'return=minimal',
        },
        body: jsonEncode(soundRows),
      );

      if (insertRes.statusCode == 201) {
        print('  Inserted ${soundRows.length} sounds into DB');
      } else {
        print('  DB insert failed: ${insertRes.statusCode} ${insertRes.body}');
      }
    }

    categoryIndex++;
  }

  print('\nDone! All sounds generated and uploaded.');
}

Future<Map<String, String>> _readEnvFile() async {
  final file = Uri.file('.env');
  final content = await http.read(file);
  final map = <String, String>{};
  for (final line in content.split('\n')) {
    if (line.contains('=') && !line.startsWith('#')) {
      final parts = line.split('=');
      map[parts[0].trim()] = parts.sublist(1).join('=').trim();
    }
  }
  return map;
}
