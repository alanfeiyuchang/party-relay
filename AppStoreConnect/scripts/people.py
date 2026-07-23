"""Reusable flat-illustration 'party person' SVG snippets for promo art."""

def person_svg(pose="cheer", skin="#e8b08a", shirt="#ff6b6b", hair="#3a2a20", mirror=False, hair_style="short"):
    """Returns an SVG <g> fragment (viewBox 0 0 240 320) of a bust-up person."""
    flip = 'transform="scale(-1,1) translate(-240,0)"' if mirror else ""

    hair_shapes = {
        "short": f'<path d="M70 90 Q120 30 170 90 L170 110 Q120 75 70 110 Z" fill="{hair}"/>',
        "bun": f'<circle cx="120" cy="55" r="16" fill="{hair}"/><path d="M68 95 Q120 40 172 95 L172 112 Q120 80 68 112 Z" fill="{hair}"/>',
        "wavy": f'<path d="M62 95 Q80 35 120 40 Q160 35 178 95 Q168 70 120 72 Q72 70 62 95 Z" fill="{hair}"/>',
    }
    hair_svg = hair_shapes.get(hair_style, hair_shapes["short"])

    arms = {
        # both arms raised, cheering
        "cheer": f'''
            <rect x="30" y="120" width="38" height="110" rx="19" fill="{shirt}" transform="rotate(-35 30 120)"/>
            <circle cx="14" cy="60" r="20" fill="{skin}" transform="rotate(-35 30 120)"/>
            <rect x="172" y="120" width="38" height="110" rx="19" fill="{shirt}" transform="rotate(35 172 120)"/>
            <circle cx="226" cy="60" r="20" fill="{skin}" transform="rotate(35 172 120)"/>
        ''',
        # one arm up waving/pointing, other resting on hip
        "wave": f'''
            <rect x="165" y="110" width="36" height="120" rx="18" fill="{shirt}" transform="rotate(20 165 110)"/>
            <circle cx="183" cy="45" r="19" fill="{skin}" transform="rotate(20 165 110)"/>
            <rect x="30" y="150" width="34" height="95" rx="17" fill="{shirt}" transform="rotate(-12 30 150)"/>
            <circle cx="20" cy="235" r="18" fill="{skin}"/>
        ''',
        # dynamic charades pose: one bent overhead, one out to the side
        "act": f'''
            <rect x="150" y="70" width="34" height="115" rx="17" fill="{shirt}" transform="rotate(-70 150 70)"/>
            <circle cx="205" cy="35" r="19" fill="{skin}" transform="rotate(-70 150 70)"/>
            <rect x="20" y="140" width="34" height="120" rx="17" fill="{shirt}" transform="rotate(55 20 140)"/>
            <circle cx="65" cy="235" r="19" fill="{skin}" transform="rotate(55 20 140)"/>
        ''',
        # holding a phone up near chest with one arm, other relaxed
        "phone": f'''
            <rect x="150" y="95" width="34" height="110" rx="17" fill="{shirt}" transform="rotate(-25 150 95)"/>
            <circle cx="172" cy="35" r="18" fill="{skin}" transform="rotate(-25 150 95)"/>
            <rect x="128" y="10" width="44" height="70" rx="10" fill="#1c1c1e" transform="rotate(-25 150 95)"/>
            <rect x="30" y="150" width="34" height="95" rx="17" fill="{shirt}" transform="rotate(10 30 150)"/>
            <circle cx="45" cy="240" r="18" fill="{skin}"/>
        ''',
        # hands near face laughing
        "laugh": f'''
            <rect x="150" y="130" width="32" height="90" rx="16" fill="{shirt}" transform="rotate(-55 150 130)"/>
            <circle cx="188" cy="80" r="18" fill="{skin}" transform="rotate(-55 150 130)"/>
            <rect x="58" y="130" width="32" height="90" rx="16" fill="{shirt}" transform="rotate(55 58 130)"/>
            <circle cx="52" cy="80" r="18" fill="{skin}" transform="rotate(55 58 130)"/>
        ''',
        # sketching gesture, one arm forward
        "draw": f'''
            <rect x="150" y="140" width="34" height="100" rx="17" fill="{shirt}" transform="rotate(-95 150 140)"/>
            <circle cx="150" cy="42" r="19" fill="{skin}" transform="rotate(-95 150 140)"/>
            <rect x="30" y="155" width="32" height="90" rx="16" fill="{shirt}" transform="rotate(8 30 155)"/>
            <circle cx="38" cy="243" r="18" fill="{skin}"/>
        ''',
    }
    arm_svg = arms.get(pose, arms["cheer"])

    face = '''
        <circle cx="100" cy="98" r="7" fill="#2b2b2b"/>
        <circle cx="140" cy="98" r="7" fill="#2b2b2b"/>
        <path d="M95 118 Q120 138 145 118" stroke="#c0483d" stroke-width="7" fill="none" stroke-linecap="round"/>
        <circle cx="82" cy="112" r="10" fill="#ff9d9d" opacity="0.55"/>
        <circle cx="158" cy="112" r="10" fill="#ff9d9d" opacity="0.55"/>
    '''

    return f'''
    <g {flip}>
        {arm_svg}
        <rect x="55" y="130" width="130" height="170" rx="55" fill="{shirt}"/>
        <circle cx="120" cy="85" r="62" fill="{skin}"/>
        {face}
        {hair_svg}
    </g>
    '''


def confetti_svg(seed=0):
    """A handful of scattered confetti/streamer shapes for background decoration."""
    import math
    colors = ["#ff6b6b", "#feca57", "#a479e2", "#4a86e8", "#43d692", "#f691b3"]
    pieces = []
    rng_state = seed * 9973 + 17
    def rnd():
        nonlocal rng_state
        rng_state = (rng_state * 1103515245 + 12345) & 0x7fffffff
        return (rng_state % 1000) / 1000.0

    for i in range(26):
        x = rnd() * 1290
        y = rnd() * 2796
        c = colors[i % len(colors)]
        r = rnd()
        if r < 0.34:
            size = 14 + rnd() * 16
            rot = rnd() * 360
            pieces.append(f'<rect x="{x:.0f}" y="{y:.0f}" width="{size:.0f}" height="{size*0.4:.0f}" rx="4" fill="{c}" opacity="0.8" transform="rotate({rot:.0f} {x:.0f} {y:.0f})"/>')
        elif r < 0.67:
            radius = 7 + rnd() * 8
            pieces.append(f'<circle cx="{x:.0f}" cy="{y:.0f}" r="{radius:.0f}" fill="{c}" opacity="0.75"/>')
        else:
            size = 16 + rnd() * 10
            pieces.append(f'<polygon points="{x:.0f},{y-size:.0f} {x+size:.0f},{y+size:.0f} {x-size:.0f},{y+size:.0f}" fill="{c}" opacity="0.7"/>')
    return "\n".join(pieces)
