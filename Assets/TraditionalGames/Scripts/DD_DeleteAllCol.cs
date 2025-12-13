#if UNITY_EDITOR
using UnityEditor;
#endif
using UnityEngine;

public class DD_DeleteAllCol : MonoBehaviour
{
    [ContextMenu("Delete ALL Child Colliders (Editor)")]
    private void DeleteAllChildCollidersEditor()
    {
#if UNITY_EDITOR
        // 3D Colliders
        Collider[] cols3D = GetComponentsInChildren<Collider>(true);
        foreach (var col in cols3D)
        {
            if (col.gameObject == gameObject) continue;
            DestroyImmediate(col);
        }

        // 2D Colliders
        Collider2D[] cols2D = GetComponentsInChildren<Collider2D>(true);
        foreach (var col in cols2D)
        {
            if (col.gameObject == gameObject) continue;
            DestroyImmediate(col);
        }

        // 이 스크립트 자체도 삭제
        DestroyImmediate(this);

        Debug.Log("✅ 모든 자식 Collider 삭제 + 스크립트 제거 완료");
#endif
    }
}