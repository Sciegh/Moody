import 'package:flutter/material.dart';

/// One mood option in the composer's mood grid.
/// Mirrors an entry in the source `<script>`'s `const MOODS = [...]` array —
/// see MIGRATION_NOTES.md for the mapping. `accent`/`onAccent` are lifted
/// 1:1 from the source hex values.
@immutable
class MoodOption {
  const MoodOption({
    required this.id,
    required this.emoji,
    required this.label,
    required this.family,
    required this.accent,
    required this.onAccent,
    required this.desc,
    required this.messages,
    required this.intent,
    this.premium = false,
  });

  final String id;
  final String emoji;
  final String label;
  final String family;
  final Color accent;
  final Color onAccent;
  final String desc;
  final List<String> messages;
  final String intent;
  final bool premium;
}

const kAllMoods = <MoodOption>[
  MoodOption(
    id: 'peaceful', emoji: '🌿', label: 'Peaceful', family: 'calm',
    accent: Color(0xFF7FB7A3), onAccent: Color(0xFF0C2420),
    desc: 'A quiet, settled kind of good. Nothing urgent — just here.',
    messages: ['Feeling really peaceful right now.', 'In a calm, settled headspace today.', 'Taking a slow moment for myself.'],
    intent: 'quiet', premium: true,
  ),
  MoodOption(
    id: 'chill', emoji: '😌', label: 'Chill', family: 'calm',
    accent: Color(0xFF6FA8DC), onAccent: Color(0xFF0B2036),
    desc: 'Quiet but available — happy to hear from a friend, no pressure either way.',
    messages: ['Feeling chill today — quiet but around.', 'Taking it easy. A message is welcome, no pressure.', 'Low-key mood, nothing much going on.'],
    intent: 'available',
  ),
  MoodOption(
    id: 'content', emoji: '🙂', label: 'Content', family: 'calm',
    accent: Color(0xFF9BC49A), onAccent: Color(0xFF12291A),
    desc: 'Simple, steady, good. Nothing flashy about it.',
    messages: ['Feeling content — steady and good.', 'A quietly good day.', 'Things feel fine, in a nice way.'],
    intent: 'quiet',
  ),
  MoodOption(
    id: 'cozy', emoji: '🕯️', label: 'Cozy', family: 'calm',
    accent: Color(0xFFD8A47F), onAccent: Color(0xFF2E1B0C),
    desc: 'Warm, wrapped-up, unhurried.',
    messages: ['In full cozy mode today.', 'Wrapped up and unbothered.', 'Slow morning, warm drink, good mood.'],
    intent: 'quiet', premium: true,
  ),
  MoodOption(
    id: 'sleepy', emoji: '😴', label: 'Sleepy', family: 'calm',
    accent: Color(0xFF8E97C9), onAccent: Color(0xFF1B1E38),
    desc: 'Running low on energy — probably an early night.',
    messages: ['Sleepy today, running on low battery.', 'Might be an early night for me.', 'Barely keeping my eyes open.'],
    intent: 'quiet',
  ),
  MoodOption(
    id: 'excited', emoji: '🤩', label: 'Excited', family: 'energetic',
    accent: Color(0xFFFF8A5B), onAccent: Color(0xFF331705),
    desc: 'Buzzing about something — happy to share if you ask.',
    messages: ['Feeling so excited right now!', 'Can\'t stop smiling today.', 'Something good is happening and I\'m thrilled.'],
    intent: 'available',
  ),
  MoodOption(
    id: 'joyful', emoji: '😊', label: 'Joyful', family: 'energetic',
    accent: Color(0xFFFFC145), onAccent: Color(0xFF332504),
    desc: 'Genuinely, warmly happy.',
    messages: ['Feeling really joyful today.', 'Everything feels a little brighter right now.', 'Good mood, no particular reason needed.'],
    intent: 'available',
  ),
  MoodOption(
    id: 'playful', emoji: '😜', label: 'Playful', family: 'energetic',
    accent: Color(0xFFFF6FA5), onAccent: Color(0xFF330A1D),
    desc: 'In the mood to joke around.',
    messages: ['Feeling playful — send memes.', 'In a silly mood today.', 'Up for some fun if anyone\'s around.'],
    intent: 'available',
  ),
  MoodOption(
    id: 'motivated', emoji: '🔥', label: 'Motivated', family: 'energetic',
    accent: Color(0xFFF4845F), onAccent: Color(0xFF2E0F04),
    desc: 'Locked in and ready to get things done.',
    messages: ['Feeling motivated — getting things done today.', 'On a roll and don\'t want to stop.', 'Ready to tackle my list.'],
    intent: 'quiet', premium: true,
  ),
  MoodOption(
    id: 'confident', emoji: '💪', label: 'Confident', family: 'energetic',
    accent: Color(0xFFFFB703), onAccent: Color(0xFF332400),
    desc: 'Sure of yourself today, in a good way.',
    messages: ['Feeling confident today.', 'Trusting myself a little more right now.', 'Walking a bit taller today.'],
    intent: 'available', premium: true,
  ),
  MoodOption(
    id: 'celebratory', emoji: '🎉', label: 'Celebratory', family: 'energetic',
    accent: Color(0xFFC77DFF), onAccent: Color(0xFF250433),
    desc: 'Something worth marking — big or small.',
    messages: ['Celebrating something today! 🎉', 'Good news I want to share.', 'Today calls for celebrating.'],
    intent: 'celebrating', premium: true,
  ),
  MoodOption(
    id: 'grateful', emoji: '🙏', label: 'Grateful', family: 'social',
    accent: Color(0xFFF6BD60), onAccent: Color(0xFF332400),
    desc: 'Noticing the good stuff today.',
    messages: ['Feeling really grateful right now.', 'Counting my blessings today.', 'Thankful for the people around me.'],
    intent: 'available', premium: true,
  ),
  MoodOption(
    id: 'loved', emoji: '🥰', label: 'Loved', family: 'social',
    accent: Color(0xFFF25C78), onAccent: Color(0xFF330911),
    desc: 'Feeling cared for and connected.',
    messages: ['Feeling loved today.', 'Grateful for the people in my corner.', 'Feeling really cared for right now.'],
    intent: 'available',
  ),
  MoodOption(
    id: 'social', emoji: '👋', label: 'Social', family: 'social',
    accent: Color(0xFFFF7EB6), onAccent: Color(0xFF330A1D),
    desc: 'Craving company — down to hang or chat.',
    messages: ['Feeling social — who\'s around?', 'In the mood to hang out.', 'Come talk to me, I\'m bored of my own thoughts.'],
    intent: 'available', premium: true,
  ),
  MoodOption(
    id: 'flirty', emoji: '😏', label: 'Flirty', family: 'social',
    accent: Color(0xFFFF5DA2), onAccent: Color(0xFF330A1D),
    desc: 'In a lighthearted, flirty mood.',
    messages: ['Feeling a little flirty today 😏', 'In the mood for some banter.', 'Charm mode: on.'],
    intent: 'available',
  ),
  MoodOption(
    id: 'curious', emoji: '🔎', label: 'Curious', family: 'social',
    accent: Color(0xFFB5E48C), onAccent: Color(0xFF132106),
    desc: 'Full of questions today.',
    messages: ['Feeling curious — tell me something interesting.', 'Down a rabbit hole today.', 'In a wondering, asking-questions mood.'],
    intent: 'available', premium: true,
  ),
  MoodOption(
    id: 'sad', emoji: '😢', label: 'Sad', family: 'heavy',
    accent: Color(0xFF6B7A99), onAccent: Color(0xFFEDEFF5),
    desc: 'Having a heavier day. Sharing it is enough — no need to fix anything.',
    messages: ['Having a sad day today.', 'Feeling a bit down right now.', 'Not my best day, but I\'m okay.'],
    intent: 'checkin',
  ),
  MoodOption(
    id: 'melancholy', emoji: '🌧️', label: 'Melancholy', family: 'heavy',
    accent: Color(0xFF7D6E83), onAccent: Color(0xFFF0EAF2),
    desc: 'A soft, wistful kind of low.',
    messages: ['Feeling melancholy today.', 'In a reflective, quiet-sad mood.', 'Nothing\'s wrong, just feeling a little heavy.'],
    intent: 'quiet', premium: true,
  ),
  MoodOption(
    id: 'heartbroken', emoji: '💔', label: 'Heartbroken', family: 'heavy',
    accent: Color(0xFF8C5B6B), onAccent: Color(0xFFF5E9ED),
    desc: 'Going through something painful right now.',
    messages: ['Feeling heartbroken today.', 'Having a really hard time right now.', 'Could use a distraction, or just company.'],
    intent: 'checkin', premium: true,
  ),
  MoodOption(
    id: 'lonely', emoji: '😔', label: 'Lonely', family: 'heavy',
    accent: Color(0xFF5C6B8A), onAccent: Color(0xFFECEFF6),
    desc: 'Missing connection today.',
    messages: ['Feeling lonely today.', 'Could use some company if anyone\'s free.', 'Missing people a bit more than usual.'],
    intent: 'checkin',
  ),
  MoodOption(
    id: 'drained', emoji: '🔋', label: 'Drained', family: 'heavy',
    accent: Color(0xFF6E6E6E), onAccent: Color(0xFFF2F2F2),
    desc: 'Running on empty — low energy for anything extra.',
    messages: ['Feeling drained today.', 'Running on empty, taking it slow.', 'Not much left in the tank today.'],
    intent: 'quiet', premium: true,
  ),
  MoodOption(
    id: 'overwhelmed', emoji: '🌊', label: 'Overwhelmed', family: 'heavy',
    accent: Color(0xFF5E6B94), onAccent: Color(0xFFEDEFF6),
    desc: 'A lot is happening at once right now.',
    messages: ['Feeling overwhelmed today.', 'A lot on my plate right now.', 'Taking things one thing at a time today.'],
    intent: 'quiet', premium: true,
  ),
  MoodOption(
    id: 'anxious', emoji: '😬', label: 'Anxious', family: 'anxious',
    accent: Color(0xFFD9A441), onAccent: Color(0xFF2E2000),
    desc: 'On edge right now. No need to reply — just wanted to share.',
    messages: ['Feeling anxious today.', 'A little on edge right now.', 'Mind\'s been racing today.'],
    intent: 'quiet',
  ),
  MoodOption(
    id: 'nervous', emoji: '😅', label: 'Nervous', family: 'anxious',
    accent: Color(0xFFC9A0DC), onAccent: Color(0xFF25092E),
    desc: 'Something\'s got you keyed up.',
    messages: ['Feeling nervous about something today.', 'A little jittery right now.', 'Got something on my mind today.'],
    intent: 'quiet',
  ),
  MoodOption(
    id: 'stressed', emoji: '😣', label: 'Stressed', family: 'anxious',
    accent: Color(0xFFE07A5F), onAccent: Color(0xFF2E0F04),
    desc: 'A lot of pressure right now.',
    messages: ['Feeling stressed today.', 'Under a lot of pressure right now.', 'Just trying to get through today.'],
    intent: 'quiet',
  ),
  MoodOption(
    id: 'restless', emoji: '🌀', label: 'Restless', family: 'anxious',
    accent: Color(0xFFD4C860), onAccent: Color(0xFF2E2A00),
    desc: 'Can\'t quite settle today.',
    messages: ['Feeling restless today.', 'Can\'t sit still today.', 'Need to move, do something, anything.'],
    intent: 'quiet', premium: true,
  ),
  MoodOption(
    id: 'irritable', emoji: '😤', label: 'Irritable', family: 'anxious',
    accent: Color(0xFFE4572E), onAccent: Color(0xFFF7E4DB),
    desc: 'Patience is a little thin today.',
    messages: ['Feeling irritable today.', 'Patience running short right now.', 'Snappier than usual today — not you, just me.'],
    intent: 'quiet',
  ),
  MoodOption(
    id: 'tired', emoji: '🥱', label: 'Tired', family: 'heavy',
    accent: Color(0xFF7A7F87), onAccent: Color(0xFFF1F1F2),
    desc: 'Worn out, physically or mentally.',
    messages: ['Feeling really tired today.', 'Worn out today, taking it slow.', 'Low energy — resting when I can.'],
    intent: 'quiet',
  ),
  MoodOption(
    id: 'uncertain', emoji: '🤔', label: 'Uncertain', family: 'anxious',
    accent: Color(0xFFB8B8B8), onAccent: Color(0xFF1F1F1F),
    desc: 'Not quite sure how you feel — and that\'s okay.',
    messages: ['Not totally sure how I feel today.', 'Kind of an in-between day.', 'Hard to put today into words.'],
    intent: 'quiet',
  ),
  MoodOption(
    id: 'serene', emoji: '🕊️', label: 'Serene', family: 'calm',
    accent: Color(0xFF8FD6C1), onAccent: Color(0xFF0D2620),
    desc: 'Still water. Nothing pulling at you right now.',
    messages: ['Feeling serene today.', 'Everything feels still and easy right now.', 'A quiet, untroubled kind of day.'],
    intent: 'quiet', premium: true,
  ),
  MoodOption(
    id: 'grounded', emoji: '🌱', label: 'Grounded', family: 'calm',
    accent: Color(0xFFA9C97E), onAccent: Color(0xFF1B2707),
    desc: 'Steady on your feet, whatever else is going on.',
    messages: ['Feeling grounded today.', 'Steady, no matter what\'s happening around me.', 'Rooted and okay today.'],
    intent: 'quiet', premium: true,
  ),
  MoodOption(
    id: 'zen', emoji: '🧘', label: 'Zen', family: 'calm',
    accent: Color(0xFF9FD8D3), onAccent: Color(0xFF0B2422),
    desc: 'Deluxe. Fully unbothered, mind clear.',
    messages: ['Feeling zen today — mind is clear.', 'Nothing\'s rattling me today.', 'Fully at peace right now.'],
    intent: 'quiet', premium: true,
  ),
  MoodOption(
    id: 'dreamy', emoji: '☁️', label: 'Dreamy', family: 'calm',
    accent: Color(0xFFC3B1E1), onAccent: Color(0xFF241735),
    desc: 'Deluxe. Soft-focus, a little bit far away today.',
    messages: ['Feeling dreamy today.', 'Head in the clouds, in a good way.', 'Drifting through today, softly.'],
    intent: 'quiet', premium: true,
  ),
  MoodOption(
    id: 'inspired', emoji: '✨', label: 'Inspired', family: 'energetic',
    accent: Color(0xFFFFD166), onAccent: Color(0xFF332600),
    desc: 'Full of ideas and itching to start something.',
    messages: ['Feeling inspired today.', 'Full of ideas I want to chase.', 'Something sparked and I\'m running with it.'],
    intent: 'available', premium: true,
  ),
  MoodOption(
    id: 'giddy', emoji: '🥳', label: 'Giddy', family: 'energetic',
    accent: Color(0xFFFF9F6B), onAccent: Color(0xFF331705),
    desc: 'Bouncy, bright, can\'t quite sit still with excitement.',
    messages: ['Feeling giddy today!', 'Can\'t stop bouncing today.', 'In a bubbly, bright mood.'],
    intent: 'available',
  ),
  MoodOption(
    id: 'adventurous', emoji: '🧭', label: 'Adventurous', family: 'energetic',
    accent: Color(0xFF4FBF8B), onAccent: Color(0xFF072418),
    desc: 'Deluxe. Ready to say yes to something new.',
    messages: ['Feeling adventurous today.', 'Up for anything today — surprise me.', 'Chasing something new today.'],
    intent: 'available', premium: true,
  ),
  MoodOption(
    id: 'unstoppable', emoji: '🚀', label: 'Unstoppable', family: 'energetic',
    accent: Color(0xFFFF4D6D), onAccent: Color(0xFF33000A),
    desc: 'Deluxe. Big energy, nothing\'s slowing you down today.',
    messages: ['Feeling unstoppable today.', 'On fire and not stopping today.', 'Big momentum today — watch out.'],
    intent: 'available', premium: true,
  ),
  MoodOption(
    id: 'proud', emoji: '🦁', label: 'Proud', family: 'energetic',
    accent: Color(0xFFFFB84D), onAccent: Color(0xFF331F00),
    desc: 'Deluxe. Standing a little taller about something you did.',
    messages: ['Feeling proud of myself today.', 'Gave myself credit for something today.', 'Standing a little taller today.'],
    intent: 'available', premium: true,
  ),
  MoodOption(
    id: 'chatty', emoji: '💬', label: 'Chatty', family: 'social',
    accent: Color(0xFFFF9EC4), onAccent: Color(0xFF330A1D),
    desc: 'Talkative and ready for a real conversation.',
    messages: ['Feeling chatty today — hit me up.', 'In a talkative mood today.', 'Down for a long conversation today.'],
    intent: 'available', premium: true,
  ),
  MoodOption(
    id: 'affectionate', emoji: '🤗', label: 'Affectionate', family: 'social',
    accent: Color(0xFFF4978E), onAccent: Color(0xFF330A08),
    desc: 'Warm toward the people around you today.',
    messages: ['Feeling affectionate today.', 'Sending love to the people around me today.', 'Feeling extra warm toward my people today.'],
    intent: 'available',
  ),
  MoodOption(
    id: 'romantic', emoji: '🌹', label: 'Romantic', family: 'social',
    accent: Color(0xFFE4567E), onAccent: Color(0xFF33071A),
    desc: 'Deluxe. Soft, swoony, thinking about someone.',
    messages: ['Feeling romantic today 🌹', 'In a swoony mood today.', 'Thinking about someone today.'],
    intent: 'available', premium: true,
  ),
  MoodOption(
    id: 'goofy', emoji: '🤪', label: 'Goofy', family: 'social',
    accent: Color(0xFFFFCE54), onAccent: Color(0xFF332600),
    desc: 'Deluxe. Zero chill, full nonsense mode.',
    messages: ['Feeling extremely goofy today.', 'Zero chill today, full nonsense mode.', 'In a ridiculous mood — come laugh with me.'],
    intent: 'available',
  ),
  MoodOption(
    id: 'charming', emoji: '🎩', label: 'Charming', family: 'social',
    accent: Color(0xFFC08EFF), onAccent: Color(0xFF1E0433),
    desc: 'Deluxe. Feeling a little smooth today.',
    messages: ['Feeling charming today.', 'Bringing the charm today.', 'Smooth mood today — try me.'],
    intent: 'available', premium: true,
  ),
  MoodOption(
    id: 'homesick', emoji: '🏠', label: 'Homesick', family: 'heavy',
    accent: Color(0xFF7B8FA1), onAccent: Color(0xFFEEF2F5),
    desc: 'Missing a place, or the people in it.',
    messages: ['Feeling homesick today.', 'Missing home a bit more than usual.', 'Wishing I were somewhere familiar today.'],
    intent: 'checkin', premium: true,
  ),
  MoodOption(
    id: 'disappointed', emoji: '😞', label: 'Disappointed', family: 'heavy',
    accent: Color(0xFF8A7B93), onAccent: Color(0xFFF2EEF5),
    desc: 'Something didn\'t go the way you hoped.',
    messages: ['Feeling disappointed today.', 'Something didn\'t go the way I hoped.', 'A letdown today, but I\'ll be okay.'],
    intent: 'quiet',
  ),
  MoodOption(
    id: 'numb', emoji: '😑', label: 'Numb', family: 'heavy',
    accent: Color(0xFF71797E), onAccent: Color(0xFFF1F2F2),
    desc: 'Not really feeling much of anything right now.',
    messages: ['Feeling pretty numb today.', 'Not feeling much of anything today.', 'Just going through the motions today.'],
    intent: 'quiet',
  ),
  MoodOption(
    id: 'embarrassed', emoji: '😳', label: 'Embarrassed', family: 'heavy',
    accent: Color(0xFFB97C87), onAccent: Color(0xFFF7E9EC),
    desc: 'Still a little red about something today.',
    messages: ['Feeling embarrassed today.', 'Cringing about something today.', 'Still a little red about earlier.'],
    intent: 'quiet',
  ),
  MoodOption(
    id: 'worried', emoji: '😟', label: 'Worried', family: 'anxious',
    accent: Color(0xFFC99A55), onAccent: Color(0xFF2E2000),
    desc: 'Something\'s sitting heavy on your mind today.',
    messages: ['Feeling worried today.', 'Something\'s weighing on my mind today.', 'Can\'t stop thinking about something today.'],
    intent: 'quiet',
  ),
  MoodOption(
    id: 'impatient', emoji: '⏱️', label: 'Impatient', family: 'anxious',
    accent: Color(0xFFD97757), onAccent: Color(0xFF2E0F04),
    desc: 'Waiting on something and it\'s wearing thin.',
    messages: ['Feeling impatient today.', 'Waiting on something and it\'s getting old.', 'Ready for something to just happen already.'],
    intent: 'quiet', premium: true,
  ),
  MoodOption(
    id: 'jealous', emoji: '😒', label: 'Jealous', family: 'anxious',
    accent: Color(0xFF6B8E5A), onAccent: Color(0xFF101F0A),
    desc: 'Comparing today, even though you\'d rather not.',
    messages: ['Feeling a little jealous today.', 'Comparing myself to others more than I\'d like today.', 'Not my favorite feeling today, but it\'s honest.'],
    intent: 'quiet',
  ),
  MoodOption(
    id: 'conflicted', emoji: '🤷', label: 'Conflicted', family: 'anxious',
    accent: Color(0xFFA0A0A0), onAccent: Color(0xFF1F1F1F),
    desc: 'Torn between two ways of feeling about something.',
    messages: ['Feeling conflicted today.', 'Torn about something today.', 'Two minds about something today.'],
    intent: 'quiet', premium: true,
  ),
];

const kFamilyLabels = <String, String>{
  'calm': 'Calm', 'energetic': 'Energized', 'social': 'Social', 'heavy': 'Heavy', 'anxious': 'Anxious',
};
const kFilters = <String>['all', 'calm', 'energetic', 'social', 'heavy', 'anxious'];

class MoodIntent {
  const MoodIntent(this.id, this.label);
  final String id;
  final String label;
}

const kIntents = <MoodIntent>[
  MoodIntent('available', 'Available to talk'),
  MoodIntent('quiet', 'Quiet but okay'),
  MoodIntent('checkin', 'Please check in'),
  MoodIntent('celebrating', 'Celebrating'),
  MoodIntent('space', 'Need space'),
];