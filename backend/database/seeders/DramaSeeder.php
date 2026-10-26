<?php

namespace Database\Seeders;

use App\Models\Category;
use App\Models\Company;
use App\Models\Drama;
use App\Models\Tag;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

/**
 * 32 original African-set short dramas with episodes. All titles and synopses are original to Afriva.
 */
class DramaSeeder extends Seeder
{
    public const VIDEOS = [
        'https://storage.googleapis.com/gtv-videos-bucket/sample/ForBiggerBlazes.mp4',
        'https://storage.googleapis.com/gtv-videos-bucket/sample/ForBiggerEscapes.mp4',
        'https://storage.googleapis.com/gtv-videos-bucket/sample/ForBiggerFun.mp4',
        'https://storage.googleapis.com/gtv-videos-bucket/sample/ForBiggerJoyrides.mp4',
        'https://storage.googleapis.com/gtv-videos-bucket/sample/ForBiggerMeltdowns.mp4',
    ];

    /**
     * [title, company slug, categories, tags, badge, featured, episodes, language, synopsis]
     */
    public static function catalogue(): array
    {
        return [
            ["The Chief's Hidden Heir", 'kilima-studios', ['Family', 'Historical'], ['Secret Identity', 'Royal Bloodline', 'Inheritance'], 'hot', true, 60, 'sw',
                'When the old chief of Usambara dies, a humble boda-boda rider from Tanga discovers he is the son the clan elders hid for twenty-five years. Now three ambitious uncles want him gone before the coronation.'],
            ['Married to the Mogul of Masaki', 'kilima-studios', ['Romance', 'Billionaire'], ['Contract Marriage', 'Billionaire', 'Enemies to Lovers'], 'hot', true, 72, 'sw',
                'To save her mother\'s tailoring shop in Kariakoo, Neema signs a one-year marriage contract with the coldest property tycoon in Masaki. The rules are simple: no feelings. He breaks the first one on day three.'],
            ['Bride of Kilimanjaro', 'kilima-studios', ['Romance', 'Village Life'], ['Arranged Marriage', 'Mountain Love', 'Chagga Culture'], 'new', false, 48, 'sw',
                'Promised since childhood to a coffee farmer\'s son on the slopes of Kilimanjaro, Rehema returns from university in Dodoma with a fiancé of her own, and two families ready for war.'],
            ['Revenge of the Maasai Princess', 'savannah-pictures', ['Revenge', 'Historical'], ['Royal Bloodline', 'Strong Heroine', 'Betrayal'], 'hot', true, 80, 'en',
                'Betrayed by her husband and left for dead on the plains of Narok, Naserian survives with nothing but her grandmother\'s spear and a memory of every face that laughed. Seven years later, she comes home.'],
            ['My CEO is a Fisherman', 'zanzibar-tales', ['Romance', 'Comedy', 'Billionaire'], ['Secret Identity', 'Billionaire', 'Coastal'], 'vip', true, 64, 'sw',
                'Zuhura thinks the charming fisherman who fixes her nets in Nungwi is broke. She has no idea he owns the hotel chain she is about to sue.'],
            ['Love in Stone Town', 'zanzibar-tales', ['Romance'], ['Forbidden Love', 'Coastal', 'Rich and Poor'], 'new', true, 40, 'sw',
                'A carved-door restorer and the daughter of Stone Town\'s strictest spice merchant fall in love through the narrow alleys at night, one secret meeting at a time.'],
            ['Second Wife, First Love', 'lagos-reel-house', ['Romance', 'Family'], ['Polygamy', 'Second Chance', 'Family Secrets'], 'hot', false, 70, 'en',
                'Adaeze agrees to become the second wife of a wealthy Lagos businessman to pay her brother\'s hospital bills, only to discover the first wife is the woman who once stole her fiancé.'],
            ["The Billionaire's Village Girl", 'lagos-reel-house', ['Romance', 'Billionaire', 'Village Life'], ['Cinderella', 'Billionaire', 'Rich and Poor'], 'vip', true, 66, 'en',
                'A tech billionaire crashes his car outside a village in Enugu and wakes up with no memory, nursed by the palm-wine seller\'s daughter. By the time his family finds him, he does not want to leave.'],
            ['Daughter of the Dhow Captain', 'zanzibar-tales', ['Family', 'Historical'], ['Ocean', 'Coming of Age', 'Strong Heroine'], null, false, 36, 'sw',
                'In 1960s Pemba, the only daughter of a legendary dhow captain disguises herself as a boy to sail his final voyage and clear his name.'],
            ["The Governor's Fake Fiancée", 'lagos-reel-house', ['Romance', 'Comedy'], ['Fake Relationship', 'Politics', 'Enemies to Lovers'], 'new', false, 54, 'en',
                'Three weeks before election day, a gubernatorial candidate hires a sharp-tongued event planner to pose as his fiancée. The polls love her. So, unfortunately, does he.'],
            ['Ashes over Arusha', 'kilima-studios', ['Thriller', 'Revenge'], ['Betrayal', 'Mystery', 'Detective'], null, false, 45, 'sw',
                'A safari lodge burns down with its owner inside. His estranged daughter, now a police inspector, has seventy-two hours to prove it was murder before the insurance money vanishes.'],
            ['Campus Queen of Dar', 'kilima-studios', ['Campus', 'Romance', 'Comedy'], ['University', 'Rivals to Lovers', 'Music'], 'new', false, 30, 'sw',
                'The most popular girl at university in Dar es Salaam loses the student-government election to a quiet engineering student. She vows to ruin his semester. He has other plans.'],
            ['Blood of the Kikuyu Ridge', 'savannah-pictures', ['Family', 'Revenge'], ['Land Dispute', 'Inheritance', 'Family Secrets'], null, false, 52, 'en',
                'Four siblings return to their late father\'s tea farm in Kiambu to divide the land, and uncover a will that names a fifth heir nobody has ever met.'],
            ["The Matatu King's Secret", 'savannah-pictures', ['Comedy', 'Thriller'], ['Secret Identity', 'Nairobi Hustle', 'Crime'], 'hot', false, 44, 'sw',
                'Nairobi\'s flashiest matatu owner has a fleet of graffiti-painted buses, a loud gold chain and one dangerous secret: he is an undercover anti-corruption agent.'],
            ['Rise of the Lagos Landlady', 'lagos-reel-house', ['Comedy', 'Family'], ['Strong Heroine', 'Business', 'Rags to Riches'], null, false, 38, 'en',
                'Evicted by a greedy landlord, Mama Tolu turns a crumbling face-me-I-face-you compound into the most sought-after address in Yaba, and makes her old landlord her tenant.'],
            ['Twin Flames of Mombasa', 'savannah-pictures', ['Romance'], ['Twins', 'Mistaken Identity', 'Coastal'], 'vip', false, 58, 'sw',
                'Identical twins separated at birth swap lives for one week on Mombasa\'s Nyali beach, and both fall for the wrong person.'],
            ["The Herbalist's Curse", 'zanzibar-tales', ['Thriller', 'Village Life'], ['Supernatural', 'Mystery', 'Folklore'], null, false, 33, 'sw',
                'When every bride in a coastal village falls ill on her wedding night, a sceptical young doctor from Dar must work with the village herbalist she swore never to trust.'],
            ['Divorced, Then Crowned', 'lagos-reel-house', ['Revenge', 'Billionaire'], ['Revenge', 'Rags to Riches', 'Strong Heroine'], 'hot', true, 78, 'en',
                'Thrown out by her husband\'s family on the night of their fifth anniversary, Ifeoma signs her divorce papers smiling. They do not know she just inherited the bank that holds their mortgage.'],
            ['Kanga & Crown', 'zanzibar-tales', ['Historical', 'Romance'], ['Royal Bloodline', 'Sultanate', 'Palace Intrigue'], 'vip', false, 50, 'sw',
                'A kanga printer whose proverbs secretly carry messages between rebels is summoned to the palace, to design the wedding cloth of the prince she has been plotting against.'],
            ['The Teacher from Tabora', 'kilima-studios', ['Village Life', 'Family'], ['Second Chance', 'Rural School', 'Inspiring'], null, false, 28, 'sw',
                'A disgraced city teacher is posted to a one-room school outside Tabora. Her twelve students have never passed a national exam. She has one year to change that, and herself.'],
            ['Love Letters from Lamu', 'savannah-pictures', ['Romance', 'Historical'], ['Forbidden Love', 'Letters', 'Coastal'], 'new', false, 42, 'sw',
                'A box of unsent love letters found in a Lamu guesthouse leads a Nairobi journalist to a fifty-year-old romance, and to the grandson of the man who wrote them.'],
            ["My Husband's Secret Empire", 'lagos-reel-house', ['Thriller', 'Billionaire'], ['Secret Identity', 'Crime', 'Betrayal'], 'hot', false, 68, 'en',
                'Kemi married a mild-mannered accountant. On their first anniversary, armed men kneel before him and call him "Oga". Everything she knew was a lie.'],
            ['Heiress of the Coffee Hills', 'kilima-studios', ['Family', 'Billionaire'], ['Inheritance', 'Coffee Farm', 'Family Secrets'], null, false, 46, 'sw',
                'The youngest daughter of Mbeya\'s coffee king inherits his entire estate, on the condition that she lives on the farm, with the stepbrother who hates her, for one full harvest.'],
            ['Nairobi Nights, Kisumu Dreams', 'savannah-pictures', ['Romance', 'Campus'], ['Long Distance', 'Music', 'University'], 'new', false, 35, 'en',
                'A benga guitarist from Kisumu and a law student in Nairobi build a love story through late-night voice notes. Then her father, a judge, hears one.'],
            ["The Sultan's Last Bride", 'zanzibar-tales', ['Historical', 'Romance'], ['Arranged Marriage', 'Palace Intrigue', 'Royal Bloodline'], 'vip', false, 60, 'sw',
                'Chosen as the aging sultan\'s final bride, a fisherman\'s daughter enters a palace of whispering wives, poisoned dates and a stepson who looks at her far too long.'],
            ['Fake Pastor, Real Love', 'lagos-reel-house', ['Comedy', 'Romance'], ['Scam', 'Redemption', 'Enemies to Lovers'], null, false, 32, 'en',
                'A smooth-talking conman poses as a visiting pastor to fleece a church in Ibadan, and falls hard for the choir director who is determined to expose him.'],
            ['Return of the Disowned Son', 'kilima-studios', ['Revenge', 'Family'], ['Rags to Riches', 'Secret Identity', 'Revenge'], 'hot', false, 75, 'sw',
                'Disowned and thrown out of his family\'s Mwanza fishing empire, Juma returns ten years later as the anonymous investor who now owns forty percent of it.'],
            ['Rain Over the Serengeti', 'savannah-pictures', ['Romance', 'Village Life'], ['Wildlife Ranger', 'Second Chance', 'Nature'], null, false, 40, 'en',
                'A wildlife ranger who lost everything to poachers and a vet from Nairobi who lost her nerve meet during the great migration. Neither came looking for love.'],
            ['The Bodaboda Billionaire', 'kilima-studios', ['Comedy', 'Billionaire'], ['Secret Identity', 'Hustle', 'Rich and Poor'], 'new', false, 50, 'sw',
                'To find a wife who loves him and not his money, the heir to a Dar es Salaam conglomerate spends a year working as a boda-boda rider in Sinza.'],
            ["Mama Ntilie's Daughter", 'kilima-studios', ['Family', 'Comedy'], ['Street Food', 'Rags to Riches', 'Strong Heroine'], null, false, 26, 'sw',
                'The daughter of a roadside food vendor enters a national cooking competition with her mother\'s secret pilau recipe, against the celebrity chef who once refused to pay her mother.'],
            ['Secrets of the Spice Island', 'zanzibar-tales', ['Thriller', 'Romance'], ['Mystery', 'Spice Trade', 'Coastal'], 'hot', false, 55, 'sw',
                'A clove-plantation heiress investigating her sister\'s disappearance uncovers a smuggling ring hidden inside Zanzibar\'s oldest spice company, and a detective she cannot trust.'],
            ['Owambe Wedding Wahala', 'lagos-reel-house', ['Comedy', 'Family'], ['Wedding', 'Family Feud', 'Comedy of Errors'], 'new', false, 24, 'en',
                'Two rival Lagos families, one wedding, three aso-ebi colour schemes and a bride who has secretly already married someone else.'],
        ];
    }

    /** Catalogue genres → scope §03 Kiswahili categories. */
    public const CATEGORY_MAP = [
        'Romance' => ['Mapenzi'],
        'Revenge' => ['Vita na Mashujaa'],
        'Billionaire' => ['Maisha'],
        'Family' => ['Maisha'],
        'Comedy' => ['Vichekesho'],
        'Thriller' => ['Siri na Mafumbo', 'Upelelezi'],
        'Historical' => ['Historia'],
        'Village Life' => ['Hadithi za Afrika'],
        'Campus' => ['Maisha'],
    ];

    public function run(): void
    {
        $companies = Company::pluck('id', 'slug');
        $categories = Category::pluck('id', 'name');
        $verifiedAt = now();
        $now = now();
        mt_srand(20240601);

        $episodeRows = [];
        foreach (self::catalogue() as $i => [$title, $companySlug, $cats, $tags, $badge, $featured, $epCount, $lang, $synopsis]) {
            $slug = Str::slug($title);

            $views = match ($badge) {
                'hot' => mt_rand(1_200_000, 3_800_000),
                'vip' => mt_rand(600_000, 1_900_000),
                'new' => mt_rand(80_000, 650_000),
                default => mt_rand(40_000, 900_000),
            };
            $release = $badge === 'new' ? $now->copy()->subDays(mt_rand(3, 50)) : $now->copy()->subDays(mt_rand(70, 420));

            $drama = Drama::updateOrCreate(['slug' => $slug], [
                'company_id' => $companies[$companySlug],
                'title' => $title,
                'synopsis' => $synopsis,
                'poster_url' => "https://picsum.photos/seed/afriva-{$slug}/600/800",
                'backdrop_url' => "https://picsum.photos/seed/afriva-{$slug}-bg/1280/720",
                'total_episodes' => $epCount,
                'free_episodes' => [8, 8, 8, 6, 10, 8][$i % 6],
                'age_rating' => ['13+', '16+', 'all', '13+', '18+', '13+'][$i % 6],
                'trailer_url' => self::VIDEOS[$i % count(self::VIDEOS)],
                'review_status' => Drama::REVIEW_APPROVED,
                'reviewed_at' => $now,
                'coins_per_episode' => [30, 30, 40, 30, 50, 30][$i % 6],
                'status' => 'published',
                'is_featured' => $featured,
                'badge' => $badge,
                'language' => $lang,
                'release_date' => $release->toDateString(),
                'views' => $views,
            ]);

            $drama->categories()->sync(collect($cats)->flatMap(fn ($c) => self::CATEGORY_MAP[$c] ?? [])->unique()->map(fn ($c) => $categories[$c])->values()->all());
            $drama->tags()->sync(Tag::idsFor($tags));

            DB::table('episodes')->where('drama_id', $drama->id)->delete();
            for ($n = 1; $n <= $epCount; $n++) {
                // Views decay along the series (people drop off), episode 1 gets the most.
                $epViews = (int) round($views * 0.18 * pow(0.955, $n - 1));
                $episodeRows[] = [
                    'drama_id' => $drama->id,
                    'number' => $n,
                    'title' => "Episode {$n}",
                    'video_url' => self::VIDEOS[($i + $n) % count(self::VIDEOS)],
                    'thumbnail_url' => "https://picsum.photos/seed/afriva-{$slug}-ep{$n}/360/640",
                    'duration_seconds' => mt_rand(75, 190),
                    'is_free' => null,
                    'views' => $epViews,
                    'review_status' => Drama::REVIEW_APPROVED,
                    'playback_verified_at' => $verifiedAt,
                    'video_status' => 'ready',
                    'created_at' => $release,
                    'updated_at' => $release,
                ];
            }
        }

        foreach (array_chunk($episodeRows, 400) as $chunk) {
            DB::table('episodes')->insert($chunk);
        }
    }
}
