from app.verifier import SequenceTracker
from app.corpus import normalize, passage, load_corpus


def tracker():
    words = ['قل', 'هو', 'الله', 'احد', 'الله', 'الصمد']
    return SequenceTracker([{'id': str(i), 'text': w, 'match': normalize(w)} for i, w in enumerate(words)])


def test_correct_recitation_and_chunk_boundaries():
    t = tracker()
    assert t.feed('ق') == []
    t.feed('ل هو الل')
    assert t.cursor == 2
    t.feed('ه احد الله الصمد', final=True)
    assert t.cursor == 6


def test_missing_word_requires_following_evidence():
    t = tracker()
    assert not any(e['type'] == 'review' for e in t.feed('قل الله '))
    events = t.feed('احد ')
    issue = next(e for e in events if e['type'] == 'review')
    assert issue['cursor'] == 1
    assert issue['confirmed_mistake'] is False


def test_substitution_and_idempotent_hold():
    t = tracker()
    events = t.feed('قل هي الله احد ', final=True)
    assert any(e['type'] == 'review' for e in events)
    assert t.feed('الله الصمد ', final=True) == []


def test_self_correction_is_not_punished():
    t = tracker()
    events = t.feed('قل هي هو الله احد الله الصمد', final=True)
    assert not any(e['type'] == 'review' for e in events)
    assert t.cursor == 6


def test_repeat_previous_word_allowed():
    t = tracker()
    events = t.feed('قل قل هو الله احد الله الصمد', final=True)
    assert t.cursor == 6
    assert not any(e['type'] == 'review' for e in events)


def test_no_omission_from_silence_or_unfinished_word():
    t = tracker()
    t.feed('قل ')
    assert t.feed('', final=True) == []
    assert t.feed('ه') == []
    assert not t.holding


def test_retry_rewinds_and_clears_old_hypothesis():
    t = tracker()
    t.feed('قل هي الله احد ', final=True)
    t.retry()
    events = t.feed('قل هو الله احد الله الصمد', final=True)
    assert any(e['type'] == 'retry_aligned' for e in events)
    assert t.cursor == 6


def test_unanchored_speech_is_unclear_not_wrong():
    t = tracker()
    events = t.feed(' '.join(['noise'] * 15), final=True)
    assert [e['type'] for e in events] == ['unclear']


def test_corpus_and_original_display_text():
    assert len(load_corpus()) == 114
    words = passage(1, 1, 1)
    assert words[0]['id'] == '1:1:1'
    assert words[0]['text'] != words[0]['match']


def test_range_validation():
    import pytest
    for args in [(0, 1, 1), (115, 1, 1), (1, 7, 2), (1, 1, 8)]:
        with pytest.raises(ValueError):
            passage(*args)


def test_uthmani_dagger_alif_accepts_common_transcription():
    t = SequenceTracker(passage(1, 2, 2))
    events = t.feed('الحمد لله رب العالمين', final=True)
    assert t.cursor == len(t.words)
    assert not any(e['type'] == 'review' for e in events)
